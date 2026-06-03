# Source this file from .bashrc or .zshrc:
#   source ~/bash_tools/src/init.sh

# Resolve this file's own directory regardless of shell
if [ -n "$ZSH_VERSION" ]; then
    _TOOLS_SRC="${${(%):-%x}:A:h}"
elif [ -n "$BASH_VERSION" ]; then
    _TOOLS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

source "$_TOOLS_SRC/app-support/homebrew.sh"
source "$_TOOLS_SRC/app-support/git.sh"
source "$_TOOLS_SRC/app-support/docker.zsh"
source "$_TOOLS_SRC/app-support/node.sh"
source "$_TOOLS_SRC/app-support/python.sh"
source "$_TOOLS_SRC/app-support/claude.sh"

# PATH additions
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
export PATH="$PATH:$HOME/.cargo/bin"

unset _TOOLS_SRC
