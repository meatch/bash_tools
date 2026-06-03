# --------------------------------------------------------------
# Git
# --------------------------------------------------------------
# Functions
function grhard {
    echo '>>>> Start clean, reset, and checkout';
    set -x;
    git clean -df;
    git reset --hard;
    git checkout .;
    echo '<<<< End clean, reset, and checkout';
}

function grib() {
    git rebase -i origin/$1
}

function removeLocalBranches() {
    # Usage: removeLocalBranches [--omit <branch1,branch2,...>]
    local omit_branches=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --omit)
                IFS=',' read -rA omit_branches <<< "$2"
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

# Code review helper — creates a worktree for review without touching your working branch
# Usage: review-branch [--branch <branch>] [--merge-to-branch <branch>]
# Options:
#   --branch          Branch to review (default: current branch)
#   --merge-to-branch Rebase onto this branch before diffing (skipped if not provided)
# Examples:
#   review-branch --branch my-feature --merge-to-branch origin/main
#   review-branch --branch origin/my-feature --merge-to-branch origin/main
review-branch() {
    local branch=""
    local merge_to_branch=""

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

    # Guard: worktree directory already exists
    if [[ -d "$worktree_path" ]]; then
        echo "❌ Directory already exists: $worktree_path"
        echo "   Remove it with: git worktree remove \"$worktree_path\""
        return 1
    fi

    # Validate the remote ref exists
    if ! git rev-parse --verify "origin/$local_branch" >/dev/null 2>&1; then
        echo "❌ Branch not found on remote: origin/$local_branch"
        return 1
    fi

    # Validate merge-to branch before doing any work
    if [[ -n "$merge_to_branch" ]]; then
        if ! git rev-parse --verify "$merge_to_branch" >/dev/null 2>&1; then
            echo "❌ Merge-to branch not found: $merge_to_branch"
            return 1
        fi
    fi

    # Create worktree — main worktree HEAD is never touched
    echo "🌳 Creating worktree at $worktree_path..."
    if git show-ref --verify --quiet "refs/heads/$local_branch"; then
        git worktree add "$worktree_path" "$local_branch" || return 1
    else
        git worktree add --track -b "$local_branch" "$worktree_path" "origin/$local_branch" || return 1
    fi

    # Rebase inside the worktree
    if [[ -n "$merge_to_branch" ]]; then
        echo "🧼 Rebasing $local_branch onto $merge_to_branch (inside worktree)..."
        (cd "$worktree_path" && git rebase "$merge_to_branch") || {
            echo "❌ Rebase failed — aborting and removing worktree."
            (cd "$worktree_path" && git rebase --abort 2>/dev/null)
            git worktree remove --force "$worktree_path"
            return 1
        }
    else
        echo "⏩ Skipping rebase (no --merge-to-branch provided)"
    fi

    # Generate diff inside the worktree folder
    local diff_base="${merge_to_branch:-origin/main}"
    local diff_file="${worktree_path}/${branch_dir}.diff.txt"

    echo "📝 Generating diff against $diff_base..."
    (cd "$worktree_path" && git diff "$diff_base"..HEAD) > "$diff_file"

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
        git worktree remove "$wt" 2>/dev/null || git worktree remove --force "$wt"
    done

    echo "✅ Done."
}

# Aliases
alias gst="git status"
alias gbv="git branch -vva"
alias gbvg="git branch -vva | grep -i $1"
alias gbvb="git for-each-ref --format='%(color:cyan)%(authordate:format:%m/%d/%Y %I:%M %p) %(align:25,left)%(color:yellow)%(authorname)%(end) %(color:reset)%(refname:strip=3)' --sort=authorname refs/remotes"
alias glo="git log --oneline"
alias gloa="git log --author=\"Mitch Gohman\" --oneline"
alias glow="git log --oneline --all --graph --decorate"
alias gfp="git fetch -p"
