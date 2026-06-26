# --------------------------------------------------------------
# Git
# --------------------------------------------------------------
# Functions
function grib() {
    git rebase -i origin/$1
}

function removeLocalBranches() {
    # Usage: removeLocalBranches [--omit <branch1,branch2,...>]
    local omit_branches=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --omit)
                if [ -n "$ZSH_VERSION" ]; then
                    IFS=',' read -rA omit_branches <<< "$2"
                else
                    IFS=',' read -ra omit_branches <<< "$2"
                fi
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: removeLocalBranches [--omit <branch1,branch2,...>]"
                return 1
                ;;
        esac
    done

    local current_branch
    current_branch=$(git symbolic-ref --short HEAD)

    local branches_to_delete=()
    while IFS= read -r branch; do
        [[ "$branch" == "$current_branch" ]] && continue
        local skip=0
        for omit in "${omit_branches[@]}"; do
            [[ "$branch" == "$omit" ]] && skip=1 && break
        done
        [[ $skip -eq 1 ]] && continue
        branches_to_delete+=("$branch")
    done < <(git branch | grep -v '^\*' | sed 's/^[[:space:]]*//')

    if [[ ${#branches_to_delete[@]} -eq 0 ]]; then
        echo "No branches to delete."
        return 0
    fi

    echo "Branches to delete:"
    for b in "${branches_to_delete[@]}"; do
        echo "  $b"
    done
    echo ""
    echo -n "Proceed? [y/N] "
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; return 0; }

    for b in "${branches_to_delete[@]}"; do
        git branch -D "$b"
    done
}

# Non-destructive conflict check — same three-way merge as `git merge`, but
# computed in memory: no working tree, index, or branch changes, nothing to abort.
# Requires git >= 2.38 for merge-tree --write-tree; older gits skip the check.
_review-branch-conflict-check() {
    local worktree_path="$1"
    local merge_to_branch="$2"

    git -C "$worktree_path" merge-tree --write-tree "$merge_to_branch" HEAD >/dev/null 2>&1
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        echo "✅ Merges cleanly into $merge_to_branch"
    elif [[ $rc -eq 1 ]]; then
        echo "⚠️  Would conflict with $merge_to_branch — GitHub will flag this on the PR"
    else
        echo "⏩ Skipping conflict check (requires git >= 2.38)"
    fi
}

# Code review helper — checks out a branch for review and writes a REVIEW.md with a ready-to-paste
# Claude prompt. Default: checks out in the current repo. --worktree: opens in a separate worktree.
# Usage: review-branch --pr <number> [--worktree] [--branch <branch>] [--merge-to-branch <branch>]
# Options:
#   --pr              PR number — auto-resolves branch and base branch via gh
#   --worktree        Check out in a separate worktree instead of the current repo
#   --branch          Branch to review (default: current branch)
#   --merge-to-branch Branch the PR targets, used for conflict check (default: origin/main)
# Examples:
#   review-branch --pr 123
#   review-branch --pr 123 --worktree
#   review-branch --branch my-feature --merge-to-branch origin/develop
review-branch() {
    local pr_number=""
    local branch=""
    local merge_to_branch="origin/main"
    local merge_to_branch_explicit=false
    local use_worktree=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --pr)              pr_number="$2"; shift 2 ;;
            --branch)          branch="$2"; shift 2 ;;
            --merge-to-branch) merge_to_branch="$2"; merge_to_branch_explicit=true; shift 2 ;;
            --worktree)        use_worktree=true; shift ;;
            *)
                echo "❌ Unknown option: $1"
                echo "   Usage: review-branch --pr <number> [--worktree] [--branch <branch>] [--merge-to-branch <branch>]"
                return 1
                ;;
        esac
    done

    # --- Shared setup ---

    local pr_url=""
    if [[ -n "$pr_number" ]]; then
        if ! command -v gh >/dev/null 2>&1; then
            echo "❌ gh CLI not found. Install with: brew install gh"
            return 1
        fi
        echo "🔍 Looking up PR #$pr_number..."
        local pr_head pr_base
        pr_head=$(gh pr view "$pr_number" --json headRefName --jq '.headRefName') || return 1
        pr_base=$(gh pr view "$pr_number" --json baseRefName --jq '.baseRefName') || return 1
        pr_url=$(gh pr view "$pr_number" --json url --jq '.url') || return 1
        [ -z "$branch" ] && branch="$pr_head"
        [[ "$merge_to_branch_explicit" == false ]] && merge_to_branch="origin/$pr_base"
    fi

    echo "🔄 Fetching latest from origin..."
    git fetch origin --prune || return 1

    local original_branch
    original_branch=$(git symbolic-ref --short HEAD)
    [ -z "$branch" ] && branch="$original_branch"

    local local_branch="${branch#origin/}"
    local branch_dir="${local_branch//\//-}"
    local repo_root
    repo_root=$(git rev-parse --show-toplevel)

    if ! git rev-parse --verify "$merge_to_branch" >/dev/null 2>&1; then
        echo "❌ Merge-to branch not found: $merge_to_branch"
        return 1
    fi

    # --- Helper: write REVIEW.md ---
    _write_review_file() {
        local dir="$1"
        if [[ -n "$pr_url" ]]; then
            cat > "${dir}/REVIEW.md" << EOF
# PR Review

Open Claude in this project, then paste:

\`\`\`
Code review this PR: $pr_url
The branch \`$local_branch\` is checked out for additional context.
\`\`\`
EOF
            echo "${dir}/REVIEW.md"
        else
            echo "$dir"
        fi
    }

    # --- In-place mode (default) ---
    if [[ "$use_worktree" == false ]]; then
        if [[ "$original_branch" != "$local_branch" ]]; then
            if ! git show-ref --verify --quiet "refs/heads/$local_branch" \
                && ! git rev-parse --verify "origin/$local_branch" >/dev/null 2>&1; then
                echo "❌ Branch not found locally or on remote: $local_branch"
                return 1
            fi
            echo "🔀 Checking out $local_branch..."
            git checkout "$local_branch" || return 1
        else
            echo "✅ Already on $local_branch"
        fi

        _review-branch-conflict-check "$repo_root" "$merge_to_branch"

        local review_file
        review_file=$(_write_review_file "$repo_root")
        [[ -n "$pr_url" ]] && code "$review_file"

        echo ""
        echo "✅ Ready to review in current project:"
        echo "   Branch: $local_branch"
        [[ -n "$pr_url" ]] && echo "   Prompt: $review_file"
        return 0
    fi

    # --- Worktree mode ---
    local worktree_path="$(dirname "$repo_root")/${branch_dir}"

    # A worktree can't be created for the currently checked-out branch — switch to main first
    if [[ "$original_branch" == "$local_branch" ]]; then
        echo "⚠️  Currently on '$local_branch' — switching to main..."
        git checkout main || return 1
    fi

    if [[ -d "$worktree_path" ]]; then
        echo "📂 Worktree already exists — refreshing..."
        if git -C "$worktree_path" rev-parse --verify "origin/$local_branch" >/dev/null 2>&1; then
            echo "⬇️  Pulling latest for $local_branch..."
            git -C "$worktree_path" reset --hard "origin/$local_branch" || return 1
        else
            echo "⏩ No remote branch origin/$local_branch — skipping pull"
        fi
    else
        if ! git show-ref --verify --quiet "refs/heads/$local_branch" \
            && ! git rev-parse --verify "origin/$local_branch" >/dev/null 2>&1; then
            echo "❌ Branch not found locally or on remote: $local_branch"
            return 1
        fi
        echo "🌳 Creating worktree at $worktree_path..."
        if git show-ref --verify --quiet "refs/heads/$local_branch"; then
            git worktree add "$worktree_path" "$local_branch" || return 1
        else
            git worktree add --track -b "$local_branch" "$worktree_path" "origin/$local_branch" || return 1
        fi
    fi

    _review-branch-conflict-check "$worktree_path" "$merge_to_branch"

    # Symlink .claude/settings.local.json so the worktree inherits the parent repo's local permissions
    if [[ -f "${repo_root}/.claude/settings.local.json" ]]; then
        mkdir -p "${worktree_path}/.claude"
        ln -sf "${repo_root}/.claude/settings.local.json" "${worktree_path}/.claude/settings.local.json"
    fi

    local review_file
    review_file=$(_write_review_file "$worktree_path")

    echo "📂 Opening worktree in new VS Code window..."
    code -n "$worktree_path" "$review_file"

    echo ""
    echo "✅ Review worktree ready:"
    echo "   Branch: $local_branch"
    echo "   Path:   $worktree_path"
    [[ -n "$pr_url" ]] && echo "   Prompt: $review_file"
    echo ""
    echo "   When done: git worktree remove \"$worktree_path\""
    echo "   Or remove all review worktrees at once: clean-worktrees"
}

# Create a new feature branch in its own worktree
# Usage: create-worktree <feature-branch> [<source-branch>]
#   feature-branch  Name of the branch to create (or reuse, if it already exists locally)
#   source-branch   Ref to branch from (default: origin/main; ignored when the branch already exists)
# If the worktree folder already exists, it is simply opened in VS Code.
# Examples:
#   create-worktree my-feature
#   create-worktree my-feature origin/develop
create-worktree() {
    local feature_branch="$1"
    local source_branch="${2:-origin/main}"

    if [ -z "$feature_branch" ]; then
        echo "❌ Missing feature branch name."
        echo "   Usage: create-worktree <feature-branch> [<source-branch>]"
        return 1
    fi

    if git remote get-url origin >/dev/null 2>&1; then
        echo "🔄 Fetching latest from origin..."
        git fetch origin --prune || return 1
    fi

    # Sanitize slashes for use as a directory name
    local branch_dir="${feature_branch//\//-}"

    # Resolve worktree path as sibling of repo root
    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    local worktree_path="$(dirname "$repo_root")/${branch_dir}"

    # Worktree directory already exists — just open it
    if [[ -d "$worktree_path" ]]; then
        echo "📂 Worktree folder already exists — opening in VS Code..."
        code -n "$worktree_path"
        return 0
    fi

    if git show-ref --verify --quiet "refs/heads/$feature_branch"; then
        # Branch already exists locally — check it out in a worktree as-is
        echo "🌳 Branch already exists — creating worktree at $worktree_path from existing branch..."
        git worktree add "$worktree_path" "$feature_branch" || return 1
        source_branch="existing local branch"
    else
        # Validate the source ref exists
        if ! git rev-parse --verify "$source_branch" >/dev/null 2>&1; then
            echo "❌ Source branch not found: $source_branch"
            return 1
        fi

        echo "🌳 Creating worktree at $worktree_path from $source_branch..."
        git worktree add "$worktree_path" -b "$feature_branch" "$source_branch" || return 1
    fi

    echo "📂 Opening worktree in new VS Code window..."
    code -n "$worktree_path"

    echo ""
    echo "✅ Worktree ready:"
    echo "   Branch: $feature_branch (from $source_branch)"
    echo "   Path:   $worktree_path"
    echo ""
    echo "   When done: git worktree remove \"$worktree_path\""
    echo "   Or remove all extra worktrees at once: clean-worktrees"
}

# Remove all review worktrees (everything except the main worktree)
clean-worktrees() {
    # Must run from the primary worktree
    local main_wt
    main_wt=$(git worktree list | head -1 | awk '{print $1}')
    local current_root
    current_root=$(git rev-parse --show-toplevel)
    if [[ "$current_root" != "$main_wt" ]]; then
        echo "❌ Run clean-worktrees from your main project folder:"
        echo "   cd \"$main_wt\""
        return 1
    fi

    local worktrees=()
    local skip_first=true

    while IFS= read -r line; do
        if $skip_first; then
            skip_first=false
            continue
        fi
        local wt_path="${line%% *}"
        worktrees+=("$wt_path")
    done < <(git worktree list)

    if [[ ${#worktrees[@]} -eq 0 ]]; then
        echo "No worktrees to remove."
        return 0
    fi

    echo "Worktrees to remove:"
    for wt in "${worktrees[@]}"; do
        echo "  $wt"
    done
    echo ""
    echo -n "Proceed? [y/N] "
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; return 0; }

    for wt in "${worktrees[@]}"; do
        echo "🗑️  Removing $wt..."
        rm -rf "$wt" && git worktree prune
    done

    echo "✅ Done."
}

# Aliases
alias gst="git status"
alias gbv="git branch -vva"
alias gbvg="git branch -vva | grep -i $1"
alias glo="git log --oneline"
alias gfp="git fetch -p"
