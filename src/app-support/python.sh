# --------------------------------------------------------------
# Python Initialization
# --------------------------------------------------------------
# User-installed Python packages (pip install --user)
export PATH="$HOME/.local/bin:$PATH"
# Python 3.9 binaries from Homebrew Python installation
export PATH="$HOME/Library/Python/3.9/bin:$PATH"

# Native installed Python homebrew
# export PATH=/opt/homebrew/opt/python@3.11/libexec/bin:$PATH

# Pyenv initialization disabled for faster shell startup
# If you need to use pyenv, run: eval "$(pyenv init - zsh)"
# if command -v pyenv >/dev/null 2>&1; then
#     eval "$(pyenv init - zsh)"
# fi

# When python 2 is called, we actually want to call installed version of python
alias python2="python"
