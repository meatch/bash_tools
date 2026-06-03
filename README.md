# meatch_prefs

Shell configuration and developer tooling library. Works in **bash and zsh**.

## Usage

### Colleagues — source the tools

Clone the repo and add one line to your `.bashrc` or `.zshrc`:

```sh
git clone <repo-url> ~/bash_tools
echo 'source ~/bash_tools/src/init.sh' >> ~/.zshrc   # or ~/.bashrc
```

Open a new terminal — all functions and aliases are available.

### Personal setup — full config with Oh My Zsh

Symlink `.zshrc` to also get the Oh My Zsh configuration:

```sh
mv ~/.zshrc ~/.zshrc.backup
ln -s ~/meatch_prefs/.zshrc ~/.zshrc
```

Requires [Oh My Zsh](https://ohmyz.sh/).

---

## Docker Tools

Free up disk space by removing Docker containers, images, volumes, and build caches — while **preserving volumes you specify**.

### Setup

```sh
cd src/app-support/docker-tools
cp config.sample.sh config.sh
```

Edit `config.sh` and add the volumes you want to keep:

```sh
PRESERVE_VOLUMES=(
    "my_mysql_volume"
    "*-wp-content"     # glob patterns supported
)
```

`config.sh` is gitignored — each developer maintains their own.

For per-project organization, see `config/noun-project.sample.sh`.

### Commands

```sh
dockerPruneAll              # full prune (asks for confirmation)
dockerPruneAll --dry-run    # preview what would be removed
dockerPruneVolumes          # volumes only
dockerPruneContainers       # containers only
dockerPruneImages           # images only
dockerPruneBuilderCache     # builder cache only
```

---

## Git Tools

```sh
# Code review via worktree — keeps your working branch untouched
review-branch --branch <branch> --merge-to-branch origin/main

# Remove all review worktrees when done (run from primary worktree)
clean-worktrees

# Bulk-delete local branches
removeLocalBranches --omit main,develop
```
