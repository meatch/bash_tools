# --------------------------------------------------------------
# The Noun Project
# --------------------------------------------------------------

tnp-restart() {
    if [[ "$1" == "--all" ]]; then
        docker compose down
        docker compose up -d
    else
        docker compose down www webpack nginx
        docker compose up -d www webpack nginx
    fi
}

# Test a feature branch in its own worktree — injects a VS Code task that runs
# JS CI checks automatically when the folder opens.
# Usage: tnp-test <feature-branch>
tnp-test() {
    local branch="$1"

    if [ -z "$branch" ]; then
        echo "❌ Missing branch name."
        echo "   Usage: tnp-test <feature-branch>"
        return 1
    fi

    echo "🔄 Fetching latest from origin..."
    git fetch origin --prune || return 1

    # Normalize: strip origin/ prefix for local branch name
    local local_branch="${branch#origin/}"
    # Sanitize slashes for use as a directory name
    local branch_dir="${local_branch//\//-}"

    # Resolve worktree path as sibling of repo root
    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    local worktree_path="$(dirname "$repo_root")/${branch_dir}"

    if [[ -d "$worktree_path" ]]; then
        echo "📂 Worktree folder already exists — refreshing..."

        if git -C "$worktree_path" rev-parse --verify "origin/$local_branch" >/dev/null 2>&1; then
            echo "⬇️  Pulling latest for $local_branch..."
            git -C "$worktree_path" reset --hard "origin/$local_branch" || return 1
        else
            echo "⏩ No remote branch origin/$local_branch — skipping pull"
        fi
    else
        # Validate the branch exists locally or on the remote
        if ! git show-ref --verify --quiet "refs/heads/$local_branch" \
            && ! git rev-parse --verify "origin/$local_branch" >/dev/null 2>&1; then
            echo "❌ Branch not found locally or on remote: $local_branch"
            return 1
        fi

        # If the branch is currently checked out here, switch to main first so
        # git allows us to create a worktree for it.
        local current_branch
        current_branch=$(git symbolic-ref --short HEAD)
        if [[ "$current_branch" == "$local_branch" ]]; then
            echo "⚠️  '$local_branch' is checked out here — switching to main first..."
            git checkout main || return 1
        fi

        echo "🌳 Creating worktree at $worktree_path..."
        if git show-ref --verify --quiet "refs/heads/$local_branch"; then
            git worktree add "$worktree_path" "$local_branch" || return 1
        else
            git worktree add --track -b "$local_branch" "$worktree_path" "origin/$local_branch" || return 1
        fi
    fi

    _worktree-link-claude-settings "$worktree_path"

    echo "⚙️  Writing VS Code tasks..."
    mkdir -p "$worktree_path/.vscode"

    cat > "$worktree_path/.vscode/settings.json" << 'EOF'
{
  "jest.enable": false,
  "jest.jestCommandLine": "yarn jest",
  "jest.runMode": "on-demand"
}
EOF

    cat > "$worktree_path/.vscode/tasks.json" << 'EOF'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "tnp:install",
      "type": "shell",
      "command": "yarn install 2>&1 | tee ci-install.log",
      "presentation": {
        "reveal": "always",
        "panel": "dedicated",
        "showReuseMessage": false
      }
    },
    {
      "label": "tnp:jest",
      "type": "shell",
      "command": "yarn jest:update 2>&1 | tee ci-jest.log",
      "dependsOn": ["tnp:install"],
      "presentation": {
        "reveal": "always",
        "panel": "dedicated",
        "showReuseMessage": false
      }
    },
    {
      "label": "tnp:prettier",
      "type": "shell",
      "command": "yarn prettier:changed 2>&1 | tee ci-prettier.log",
      "dependsOn": ["tnp:install"],
      "presentation": {
        "reveal": "always",
        "panel": "dedicated",
        "showReuseMessage": false
      }
    },
    {
      "label": "tnp:eslint",
      "type": "shell",
      "command": "yarn eslint 2>&1 | tee ci-eslint.log",
      "dependsOn": ["tnp:install"],
      "presentation": {
        "reveal": "always",
        "panel": "dedicated",
        "showReuseMessage": false
      }
    },
    {
      "label": "Run CI Checks",
      "dependsOn": ["tnp:jest", "tnp:prettier", "tnp:eslint"],
      "dependsOrder": "parallel",
      "runOptions": {
        "runOn": "folderOpen"
      }
    }
  ]
}
EOF

    # Exclude generated files from git so they don't appear in git status.
    # info/exclude is local to this worktree and never committed.
    local git_dir
    git_dir=$(git -C "$worktree_path" rev-parse --git-dir)
    local exclude_file="$git_dir/info/exclude"
    for pattern in ".vscode/settings.json" ".vscode/tasks.json" "ci-*.log"; do
        grep -qF "$pattern" "$exclude_file" 2>/dev/null || echo "$pattern" >> "$exclude_file"
    done

    echo "📂 Opening worktree in new VS Code window..."
    code -n "$worktree_path"

    echo ""
    echo "✅ Test worktree ready:"
    echo "   Branch: $local_branch"
    echo "   Path:   $worktree_path"
    echo "   ➡️  VS Code will prompt to allow the task — click Allow to start."
    echo ""
    echo "   When done: git worktree remove \"$worktree_path\""
    echo "   Or remove all extra worktrees at once: clean-worktrees"
}

# Non-destructive conflict check — same three-way merge as `git merge`, but
# computed in memory: no working tree, index, or branch changes, nothing to abort.
# Requires git >= 2.38 for merge-tree --write-tree; older gits skip the check.
_tnp-review-branch-conflict-check() {
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

# Code review helper — checks out a PR branch and writes a REVIEW.md with a ready-to-paste
# Claude prompt. Default: checks out in the current repo. --worktree: opens in a separate worktree.
# Usage: tnp-review-branch --pr <number> [--worktree] [--type peer|personal|deep] [--branch <branch>] [--merge-to-branch <branch>]
# Options:
#   --pr              PR number — auto-resolves branch and base branch via gh
#   --worktree        Check out in a separate worktree instead of the current repo
#   --type            Review type: peer, personal, or deep (default: peer)
#   --branch          Branch to review (default: current branch)
#   --merge-to-branch Branch the PR targets, used for conflict check (default: origin/main)
# Examples:
#   tnp-review-branch --pr 123
#   tnp-review-branch --pr 123 --worktree
#   tnp-review-branch --pr 123 --worktree --type personal
#   tnp-review-branch --pr 123 --worktree --type deep
#   tnp-review-branch --branch my-feature --merge-to-branch origin/develop
tnp-review-branch() {
    local pr_number=""
    local branch=""
    local merge_to_branch="origin/main"
    local merge_to_branch_explicit=false
    local use_worktree=false
    local review_type="peer"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --pr)              pr_number="$2"; shift 2 ;;
            --branch)          branch="$2"; shift 2 ;;
            --merge-to-branch) merge_to_branch="$2"; merge_to_branch_explicit=true; shift 2 ;;
            --worktree)        use_worktree=true; shift ;;
            --type)            review_type="$2"; shift 2 ;;
            *)
                echo "❌ Unknown option: $1"
                echo "   Usage: tnp-review-branch --pr <number> [--worktree] [--type peer|personal|deep] [--branch <branch>] [--merge-to-branch <branch>]"
                return 1
                ;;
        esac
    done

    case "$review_type" in
        peer|personal|deep) ;;
        *)
            echo "❌ Unknown review type: $review_type"
            echo "   Expected one of: peer, personal, deep"
            return 1
            ;;
    esac

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
        local review_label=""
        local review_summary=""
        local review_instructions=""
        local claude_prompt="Read ./REVIEW.md and perform the review."
        local pr_target="this branch"

        if [[ -n "$pr_url" ]]; then
            pr_target="$pr_url"
        fi

        case "$review_type" in
            personal)
                review_label="QUICK / Personal Pre-review"
                review_summary="Fast pre-review before opening your own PR. Changed files only. Avoid broad architecture feedback and avoid subagents unless absolutely necessary."
                review_instructions=$(cat << EOF
Pre-review my current branch before I open a PR.

The branch \`$local_branch\` is checked out locally.

Review Mode: QUICK

Scope:

- Review only the changed files.
- Focus on correctness, regressions, obvious bugs, missing tests, and confusing code.
- Skip architecture discussions unless the changes clearly affect architecture.
- Do not inspect unrelated files.
- Do not use subagents unless absolutely necessary.
- Keep feedback concise and actionable.

Return:

1. Blocking issues
2. Suggested improvements
3. Overall confidence
EOF
)
                ;;
            deep)
                review_label="DEEP / Comprehensive Review"
                review_summary="Comprehensive review for risky or architectural changes. This mode may inspect related files more broadly and may use subagents when helpful."
                review_instructions=$(cat << EOF
Code review this PR: $pr_target

The branch \`$local_branch\` is checked out locally for additional context.

Review Mode: DEEP

Take a comprehensive reviewer approach.

Before reviewing:

- Read the PR description and comments using GitHub CLI when a PR URL is available.
- Inspect the PR diff.

In addition to the Standard Review:

- Evaluate architecture.
- Evaluate long-term maintainability.
- Consider performance implications.
- Consider security implications.
- Consider API consistency.
- Cross-reference related files when useful.
- Use subagents whenever they improve review quality.

Return:

1. Blocking issues
2. Major issues
3. Minor issues
4. Architectural observations
5. Long-term recommendations
EOF
)
                ;;
            peer)
                review_label="STANDARD / Peer Review"
                review_summary="Default peer review. Focus on changed files and directly related code. Use subagents only when they provide clear value."
                review_instructions=$(cat << EOF
Code review this PR: $pr_target

The branch \`$local_branch\` is checked out locally for additional context.

Review Mode: STANDARD

Before reviewing:

- Read the PR description and comments using GitHub CLI when a PR URL is available.
- Inspect the PR diff.

Scope:

- Focus primarily on changed files.
- Read additional files only when necessary to understand the changes.
- Prioritize correctness, regressions, edge cases, tests, and maintainability of the modified code.
- Do not perform a full repository audit.
- Do not suggest broad refactors.
- Do not edit code unless requested.
- Use subagents only when they provide clear value.

Return:

1. Blocking issues
2. Major suggestions
3. Minor suggestions
4. Overall assessment
EOF
)
                ;;
        esac

        cat > "${dir}/REVIEW.md" << EOF
# PR Review

Review Type: $review_label

$review_summary

## Paste into Claude

\`\`\`text
$claude_prompt
\`\`\`

## Instructions for Claude

$review_instructions
EOF
        echo "${dir}/REVIEW.md"
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

        _tnp-review-branch-conflict-check "$repo_root" "$merge_to_branch"

        local review_file
        review_file=$(_write_review_file "$repo_root")
        code "$review_file"

        echo ""
        echo "✅ Ready to review in current project:"
        echo "   Branch: $local_branch"
        echo "   Review type: $review_type"
        echo "   Prompt: $review_file"
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

    _tnp-review-branch-conflict-check "$worktree_path" "$merge_to_branch"
    _worktree-link-claude-settings "$worktree_path"

    local review_file
    review_file=$(_write_review_file "$worktree_path")

    echo "📂 Opening worktree in new VS Code window..."
    code -n "$worktree_path" "$review_file"

    echo ""
    echo "✅ Review worktree ready:"
    echo "   Branch: $local_branch"
    echo "   Path:   $worktree_path"
    echo "   Review type: $review_type"
    echo "   Prompt: $review_file"
    echo ""
    echo "   When done: git worktree remove \"$worktree_path\""
    echo "   Or remove all review worktrees at once: clean-worktrees"
}
