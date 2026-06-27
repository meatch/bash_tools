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

# Symlink .claude/settings.local.json from the primary repo into a worktree so
# it inherits local Claude permissions without duplicating the file.
_worktree-link-claude-settings() {
    local worktree_path="$1"
    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    if [[ -f "${repo_root}/.claude/settings.local.json" ]]; then
        mkdir -p "${worktree_path}/.claude"
        ln -sf "${repo_root}/.claude/settings.local.json" "${worktree_path}/.claude/settings.local.json"
    fi
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

    _worktree-link-claude-settings "$worktree_path"

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
