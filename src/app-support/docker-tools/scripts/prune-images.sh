#!/bin/bash

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$THIS_SCRIPT_DIR/shared.sh"

echo "Pre-removal: Docker Images:"
docker image ls

echo "Removing all unused Docker images..."
docker image prune -a -f

echo "Post-removal: Docker Images:"
docker image ls
