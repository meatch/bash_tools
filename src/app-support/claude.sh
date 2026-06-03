#===================================
#
# Claude Code - Anthropic's CLI
#
#===================================

# --------------------------------------------------------------
# Claude Code Setup
# --------------------------------------------------------------
# Add Claude to PATH if installed via npm global
if [ -d "$HOME/.npm-global/bin" ]; then
    export PATH="$HOME/.npm-global/bin:$PATH"
fi

# Add common Claude installation locations to PATH
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# If Claude is installed via Homebrew, it should already be in PATH
# through the homebrew.sh configuration
