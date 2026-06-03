#!/bin/bash

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$THIS_SCRIPT_DIR/shared.sh"

echo "Removing all Docker builder caches..."
docker builder prune --all -f
