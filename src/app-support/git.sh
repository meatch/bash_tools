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
        echo "⚠️  Would conflict with $merge_to_branch — diff is still reviewable; GitHub will flag the conflict on the PR"
    else
        echo "⏩ Skipping conflict check (requires git >= 2.38)"
    fi
}

# Code review helper — creates a worktree for review without touching your working branch
# Diff is generated with three dots (merge-base..branch), so it shows only the
# branch's own changes — same as a GitHub PR diff — even when other work has
# already merged to the destination branch. No rebase, history is untouched.
# Usage: review-branch [--branch <branch>] [--merge-to-branch <branch>]
# Options:
#   --branch          Branch to review (default: current branch)
#   --merge-to-branch Branch the PR targets, used as the diff base (default: origin/main)
# Examples:
#   review-branch --branch my-feature
#   review-branch --branch origin/my-feature --merge-to-branch origin/develop
review-branch() {
    local branch=""
    local merge_to_branch="origin/main"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --branch)
                branch="$2"
                shift 2
                ;;
            --merge-to-branch)
                merge_to_branch="$2"
                shift 2
                ;;
            *)
                echo "❌ Unknown option: $1"
                echo "   Usage: review-branch [--branch <branch>] [--merge-to-branch <branch>]"
                return 1
                ;;
        esac
    done

    echo "🔄 Fetching latest from origin..."
    git fetch origin --prune || return 1

    local original_branch
    original_branch=$(git symbolic-ref --short HEAD)

    # Default to current branch
    if [ -z "$branch" ]; then
        branch="$original_branch"
    fi

    # Normalize: strip origin/ prefix for local branch name
    local local_branch="${branch#origin/}"
    # Sanitize slashes for use as a directory name
    local branch_dir="${local_branch//\//-}"

    # Resolve worktree path as sibling of repo root
    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    local worktree_path="$(dirname "$repo_root")/${branch_dir}"

    # Guard: can't add a worktree for the currently checked-out branch
    if [[ "$original_branch" == "$local_branch" ]]; then
        echo "❌ You are currently on '$local_branch' in this worktree."
        echo "   Switch to another branch first, then re-run."
        return 1
    fi

    # Validate merge-to branch before doing any work
    if ! git rev-parse --verify "$merge_to_branch" >/dev/null 2>&1; then
        echo "❌ Merge-to branch not found: $merge_to_branch"
        return 1
    fi

    local diff_file="${worktree_path}/${branch_dir}.diff.txt"

    # Worktree directory already exists — refresh it, then open it
    if [[ -d "$worktree_path" ]]; then
        echo "📂 Worktree folder already exists — refreshing..."

        if git -C "$worktree_path" rev-parse --verify "origin/$local_branch" >/dev/null 2>&1; then
            echo "⬇️  Pulling latest for $local_branch..."
            git -C "$worktree_path" reset --hard "origin/$local_branch" || return 1
        else
            echo "⏩ No remote branch origin/$local_branch — skipping pull"
        fi

        _review-branch-conflict-check "$worktree_path" "$merge_to_branch"

        echo "📝 Regenerating diff against $merge_to_branch..."
        git -C "$worktree_path" diff "$merge_to_branch"...HEAD > "$diff_file"

        echo "📂 Opening worktree in VS Code..."
        code -n "$worktree_path" "$diff_file"
        return 0
    fi

    # Validate the branch exists locally or on the remote
    if ! git show-ref --verify --quiet "refs/heads/$local_branch" \
        && ! git rev-parse --verify "origin/$local_branch" >/dev/null 2>&1; then
        echo "❌ Branch not found locally or on remote: $local_branch"
        return 1
    fi

    # Create worktree — main worktree HEAD is never touched
    echo "🌳 Creating worktree at $worktree_path..."
    if git show-ref --verify --quiet "refs/heads/$local_branch"; then
        git worktree add "$worktree_path" "$local_branch" || return 1
    else
        git worktree add --track -b "$local_branch" "$worktree_path" "origin/$local_branch" || return 1
    fi

    _review-branch-conflict-check "$worktree_path" "$merge_to_branch"

    # Generate diff inside the worktree folder
    echo "📝 Generating diff against $merge_to_branch..."
    git -C "$worktree_path" diff "$merge_to_branch"...HEAD > "$diff_file"

    # Open new VS Code window: worktree as workspace, diff open as active tab
    echo "📂 Opening worktree in new VS Code window..."
    code -n "$worktree_path" "$diff_file"

    echo ""
    echo "✅ Review worktree ready:"
    echo "   Branch: $local_branch"
    echo "   Path:   $worktree_path"
    echo "   Diff:   $diff_file"
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
