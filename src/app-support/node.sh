#===================================
#
# Node
#
#===================================

# --------------------------------------------------------------
# NVM Support - Lazy Loading for faster shell startup
# NVM will auto-load the first time you use: node, npm, npx, or nvm
# --------------------------------------------------------------
export NVM_DIR="$HOME/.nvm"

# Cache brew prefix for faster lazy loading
if command -v brew >/dev/null 2>&1; then
    _CACHED_BREW_PREFIX="$(brew --prefix)"
    _CACHED_NVM_SH="$_CACHED_BREW_PREFIX/opt/nvm/nvm.sh"
fi

nvm() {
    unset -f nvm node npm npx
    [ -s "$_CACHED_NVM_SH" ] && . "$_CACHED_NVM_SH"
    nvm "$@"
}

node() {
    unset -f nvm node npm npx
    [ -s "$_CACHED_NVM_SH" ] && . "$_CACHED_NVM_SH"
    node "$@"
}

npm() {
    unset -f nvm node npm npx
    [ -s "$_CACHED_NVM_SH" ] && . "$_CACHED_NVM_SH"
    npm "$@"
}

npx() {
    unset -f nvm node npm npx
    [ -s "$_CACHED_NVM_SH" ] && . "$_CACHED_NVM_SH"
    npx "$@"
}
