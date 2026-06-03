# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A portable shell configuration and developer tooling library. Scripts target both **bash and zsh**, with or without Oh My Zsh. The primary author symlinks `~/.zshrc` → `meatch_prefs/.zshrc`. Colleagues source only `src/init.sh`.

## Loading chain

`.zshrc` → `src/init.sh` → `src/app-support/*.sh` + `src/app-support/docker-tools/index.sh`

`src/init.sh` self-locates using shell-specific path resolution, then sources every script in `src/app-support/`.

## Adding a new script

1. Create `src/app-support/foo.sh`
2. Add `source "$_TOOLS_SRC/app-support/foo.sh"` to `src/init.sh` before `unset _TOOLS_SRC`

## Shell compatibility

All `.sh` files must work in both bash and zsh. Key incompatibilities to handle:

**Array reads:**
```sh
if [ -n "$ZSH_VERSION" ]; then
    IFS=',' read -rA my_array <<< "$input"   # zsh: -A
else
    IFS=',' read -ra my_array <<< "$input"   # bash: -a
fi
```

**Self-location in a sourced file:**
```sh
if [ -n "$ZSH_VERSION" ]; then
    _DIR="${${(%):-%x}:A:h}"
elif [ -n "$BASH_VERSION" ]; then
    _DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
```

Scripts inside `docker-tools/scripts/` are called as subprocesses (`bash script.sh`), so they use only `BASH_SOURCE` — no zsh detection needed there.

## Testing changes

```sh
source ~/.zshrc       # reload in current shell
type function-name    # verify a function loaded
alias alias-name      # verify an alias loaded
```

Startup profiling: set `ENABLE_STARTUP_LOGGING=true` in `.zshrc` for total time, `ENABLE_DETAILED_PROFILING=true` for per-file breakdowns.

## NVM lazy loading

`node.sh` shadows `nvm`, `node`, `npm`, `npx` with stubs that load NVM on first use, avoiding ~200ms startup cost. The stubs unset themselves after the first real invocation.

## Docker tools (`src/app-support/docker-tools/`)

Self-contained pure-bash Docker prune tool. `index.sh` is sourced by `init.sh` and defines all shell functions. Scripts under `scripts/` are called as subprocesses and handle their own config loading.

**Config:** `config.sh` (gitignored) defines `PRESERVE_VOLUMES`. Copy from `config.sample.sh`. Per-project arrays can live in `config/*.sh` and be sourced into `config.sh` — see `config/noun-project.sample.sh`.

**Volume glob patterns** (`*-wp-content`, `project-*`) are matched via bash `case` statement in `scripts/shared.sh:volume_is_preserved()`.

## Key functions

| Function | Description |
|---|---|
| `review-branch --branch <b> --merge-to-branch <dest>` | Creates a git worktree at `../<branch-dir>`, rebases in the worktree (never touches main), generates diff, opens VS Code |
| `clean-worktrees` | Removes all non-primary worktrees; must run from the primary worktree |
| `removeLocalBranches [--omit b1,b2]` | Bulk-delete local branches with confirmation |
| `dockerPruneAll [--dry-run]` | Full Docker prune: containers → images → volumes → cache |
| `dockerPruneVolumes [--dry-run]` | Volumes only, preserving those matched by `PRESERVE_VOLUMES` |
