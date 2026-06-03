#!/bin/bash

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$THIS_SCRIPT_DIR/shared.sh"

# Handle --dry-run flag
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
fi

if [ "$DRY_RUN" = true ]; then
    step_header "Dry Run: Volumes Preview"
    bash "$THIS_SCRIPT_DIR/prune-volumes.sh" --dry-run
    exit 0
fi

confirm_execution "remove ALL Docker containers, images, volumes, and build caches"

step_header "Pre-removal: Disk Usage"
docker system df

step_header "Step 1: Containers"
bash "$THIS_SCRIPT_DIR/prune-containers.sh"

step_header "Step 2: Images"
bash "$THIS_SCRIPT_DIR/prune-images.sh"

step_header "Step 3: Volumes"
bash "$THIS_SCRIPT_DIR/prune-volumes.sh"

step_header "Step 4: Builder Cache"
bash "$THIS_SCRIPT_DIR/prune-builder-cache.sh"

step_header "Post-removal: Disk Usage"
docker system df
