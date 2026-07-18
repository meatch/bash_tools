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

# $HOMEBREW_PREFIX is exported by homebrew.sh's `brew shellenv` eval —
# reuse it instead of forking another `brew --prefix` process.
if [ -n "$HOMEBREW_PREFIX" ]; then
    _CACHED_NVM_SH="$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
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
