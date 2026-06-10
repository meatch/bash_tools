# bash_tools

Shell configuration and developer tooling library. Works in **bash and zsh**.

## Usage

### Colleagues — source the tools

Clone the repo into your home folder, then add one line to your `.bashrc` or `.zshrc`:

```sh
git clone <repo-url> ~/bash_tools
echo 'source ~/bash_tools/src/init.sh' >> ~/.zshrc   # or ~/.bashrc
```

_Note: the `~/bash_tools` location is the expected default. If you clone elsewhere, update the path in the source line accordingly._

### One-off usage — without modifying your shell config

Source `init.sh` directly in your current session, then run any command:

```sh
source ~/bash_tools/src/init.sh
dockerPruneAll --dry-run
```

Functions are available for the rest of that terminal session only.

### Personal setup — full config with Oh My Zsh

Symlink `.zshrc` to also get the Oh My Zsh configuration:

```sh
mv ~/.zshrc ~/.zshrc.backup
ln -s ~/meatch_prefs/.zshrc ~/.zshrc
```

Requires [Oh My Zsh](https://ohmyz.sh/).

### Personal scripts — unversioned local overrides

Drop any `.sh` file into `local/` and it will be sourced automatically on shell init, after all shared scripts have loaded. The directory is gitignored, so your changes stay local.

```sh
cp local/example.sample.sh local/personal.sh
# edit local/personal.sh, then:
source ~/.zshrc
```

`local/*.sample.sh` files are committed as documentation. All other `local/*.sh` files are ignored by git.

---

## Docker Tools

Free up disk space by removing Docker containers, images, volumes, and build caches — while **preserving volumes you specify**.

### Setup

Copy the config template from the repo root and add the volumes you want to keep:

```sh
cp config.sample.sh config.sh
```

```sh
PRESERVE_VOLUMES=(
    "my_mysql_volume"
    "*-wp-content"     # glob patterns supported
)
```

`config.sh` lives at the repo root and is gitignored — each developer maintains their own. For per-project volume organization, see `config/noun-project.sample.sh`.

### Commands

```sh
dockerPruneAll --dry-run    # preview what would be removed
dockerPruneAll              # full prune (asks for confirmation)
dockerPruneVolumes          # volumes only
dockerPruneContainers       # containers only
dockerPruneImages           # images only
dockerPruneBuilderCache     # builder cache only
```

---

## Git Tools

### Functions

```sh
# Code review via worktree — keeps your working branch untouched
review-branch --branch <branch> --merge-to-branch origin/main

# Start a new feature branch in its own worktree (source defaults to origin/main)
create-worktree <feature-branch> [<source-branch>]

# Remove all review worktrees when done (run from primary worktree)
clean-worktrees

# Bulk-delete local branches with confirmation
removeLocalBranches [--omit main,develop]

# Interactive rebase onto origin/<branch>
grib <branch>

# Hard reset — clean untracked files, reset, and checkout
grhard
```

### Aliases

```sh
gst     # git status
glo     # git log --oneline
gbv     # git branch -vva
gbvg    # git branch -vva | grep -i <term>
gfp     # git fetch -p
```
