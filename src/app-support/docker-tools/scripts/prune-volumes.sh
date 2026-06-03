#!/bin/bash

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$THIS_SCRIPT_DIR/shared.sh"

# Handle --dry-run flag
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "🔍 DRY RUN MODE — no volumes will be deleted"
    echo ""
fi

# Load config from repo root
CONFIG_FILE="$BASH_TOOLS_ROOT/config.sh"
if [ -z "$BASH_TOOLS_ROOT" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Missing config.sh at repo root"
    echo "   cp $BASH_TOOLS_ROOT/config.sample.sh $BASH_TOOLS_ROOT/config.sh"
    exit 1
fi

PRESERVE_VOLUMES=()
source "$CONFIG_FILE"

# Guard: PRESERVE_VOLUMES must not be empty
if [ ${#PRESERVE_VOLUMES[@]} -eq 0 ]; then
    echo "❌ PRESERVE_VOLUMES is empty in config.sh"
    echo "   Add volumes to preserve before running — otherwise everything will be removed."
    exit 1
fi

# Guard: reject bare wildcard patterns that would preserve everything
for pattern in "${PRESERVE_VOLUMES[@]}"; do
    if [[ "$pattern" == "*" ]] || [[ "$pattern" == "?" ]] || [[ "$pattern" == "**" ]]; then
        echo "❌ Overly broad pattern detected: '$pattern'"
        echo "   Use specific patterns like '*-wp-content' or 'project-*'"
        exit 1
    fi
done

echo "Preserving volumes: ${PRESERVE_VOLUMES[*]}"
echo ""
echo "Pre-removal: Docker Volumes:"
docker volume ls
echo ""

ALL_VOLUMES=$(docker volume ls --quiet)
VOLUMES_TO_REMOVE=()

for VOLUME in $ALL_VOLUMES; do
    if volume_is_preserved "$VOLUME"; then
        echo "✓ Preserving: $VOLUME"
    else
        VOLUMES_TO_REMOVE+=("$VOLUME")
        if [ "$DRY_RUN" = true ]; then
            echo "❌ Would remove: $VOLUME"
        else
            echo "Removing: $VOLUME"
            docker volume rm "$VOLUME"
        fi
    fi
done

echo ""
if [ "$DRY_RUN" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📈 DRY RUN SUMMARY"
    echo "   Would preserve: ${#PRESERVE_VOLUMES[@]} patterns"
    echo "   Would remove:   ${#VOLUMES_TO_REMOVE[@]} volumes"
    if [ ${#VOLUMES_TO_REMOVE[@]} -eq 0 ]; then
        echo "   ✅ Nothing to remove"
    else
        echo "   Run without --dry-run to apply"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "Post-removal: Docker Volumes:"
    docker volume ls
fi
