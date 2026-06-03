#!/bin/bash

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$THIS_SCRIPT_DIR/shared.sh"

echo "Stopping all running containers..."
docker container stop $(docker container ls -q) 2>/dev/null || true

echo "Removing all containers..."
docker container prune -f
