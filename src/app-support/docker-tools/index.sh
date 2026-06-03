# Docker tools — shell functions for Docker prune operations
# Sourced by src/init.sh

# Self-locate this file's directory (works when sourced from bash or zsh)
if [ -n "$ZSH_VERSION" ]; then
    _DT_DIR="${${(%):-%x}:A:h}"
elif [ -n "$BASH_VERSION" ]; then
    _DT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ ! -f "$BASH_TOOLS_ROOT/config.sh" ]; then
    echo "⚠️  docker-tools: config.sh not found."
    echo "   cd $BASH_TOOLS_ROOT && cp config.sample.sh config.sh"
fi

# Full prune: containers → images → volumes → builder cache
# Usage: dockerPruneAll [--dry-run]
dockerPruneAll() {
    bash "$_DT_DIR/scripts/prune-all.sh" "$@"
}

# Prune volumes only, skipping those in PRESERVE_VOLUMES
# Usage: dockerPruneVolumes [--dry-run]
dockerPruneVolumes() {
    bash "$_DT_DIR/scripts/prune-volumes.sh" "$@"
}

# Stop and remove all containers
dockerPruneContainers() {
    bash "$_DT_DIR/scripts/prune-containers.sh"
}

# Remove all unused images
dockerPruneImages() {
    bash "$_DT_DIR/scripts/prune-images.sh"
}

# Clear all builder caches
dockerPruneBuilderCache() {
    bash "$_DT_DIR/scripts/prune-builder-cache.sh"
}
