# Source this file from .bashrc or .zshrc:
#   source ~/bash_tools/src/init.sh

# Resolve this file's own directory regardless of shell
if [ -n "$ZSH_VERSION" ]; then
    _TOOLS_SRC="${${(%):-%x}:A:h}"
elif [ -n "$BASH_VERSION" ]; then
    _TOOLS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Export repo root so any script (including docker subprocess scripts) can find config.sh
export BASH_TOOLS_ROOT="$(dirname "$_TOOLS_SRC")"

# Source root config if present — available to all sourced scripts
if [ -f "$BASH_TOOLS_ROOT/config.sh" ]; then
    source "$BASH_TOOLS_ROOT/config.sh"
fi

source "$_TOOLS_SRC/app-support/homebrew.sh"
source "$_TOOLS_SRC/app-support/git.sh"
source "$_TOOLS_SRC/app-support/node.sh"
source "$_TOOLS_SRC/app-support/python.sh"
source "$_TOOLS_SRC/app-support/claude.sh"
source "$_TOOLS_SRC/app-support/docker-tools/index.sh"
source "$_TOOLS_SRC/app-support/tnp.sh"

# PATH additions
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
export PATH="$PATH:$HOME/.cargo/bin"

# Source any personal/unversioned scripts from local/ (gitignored)
for _f in "$BASH_TOOLS_ROOT/local/"*.sh; do
    [ -f "$_f" ] && source "$_f"
done
unset _f

unset _TOOLS_SRC
