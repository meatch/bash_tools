# --------------------------------------------------------------
# Homebrew
# --------------------------------------------------------------
# Homebrew binaries (must be early for system tools like python, node, etc.)
export PATH="/opt/homebrew/bin:$PATH"

# Ensure Homebrew environment is set (Apple Silicon)
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Shell-aware completion setup
if type brew &>/dev/null; then
    if [ -n "$ZSH_VERSION" ]; then
        # $HOMEBREW_PREFIX comes from the shellenv eval above — avoids a
        # second `brew --prefix` subprocess just to get the same value.
        FPATH="$HOMEBREW_PREFIX/share/zsh/site-functions:${FPATH}"
        # If OMZ is not loaded (no compdef), initialize completions ourselves
        if ! type compdef &>/dev/null 2>&1; then
            autoload -Uz compinit && compinit
        fi
    elif [ -n "$BASH_VERSION" ]; then
        brew_completion="$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh"
        [ -r "$brew_completion" ] && source "$brew_completion"
    fi
fi
