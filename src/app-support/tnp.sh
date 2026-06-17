# --------------------------------------------------------------
# The Noun Project
# --------------------------------------------------------------

function tnpRestart() {
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
# Usage: tnpTest <feature-branch>
tnpTest() {
    local branch="$1"

    if [ -z "$branch" ]; then
        echo "❌ Missing branch name."
        echo "   Usage: tnpTest <feature-branch>"
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
