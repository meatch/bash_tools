#!/bin/bash

# Display a formatted step header
step_header() {
    local title="$1"
    echo ""
    echo "=============================================="
    echo "$title"
    echo "=============================================="
    echo ""
}

# Prompt for confirmation before a destructive action
confirm_execution() {
    local title="$1"
    read -p "Are you sure you want to $title? [y/n]: " answer
    if [ "$answer" = "y" ]; then
        echo "Executing..."
    else
        echo "Cancelled."
        exit 1
    fi
}

# Return 0 if a volume name matches any pattern in PRESERVE_VOLUMES
# Supports glob patterns via bash case statement (* and ?)
volume_is_preserved() {
    local volume="$1"
    for pattern in "${PRESERVE_VOLUMES[@]}"; do
        case "$volume" in
            $pattern) return 0 ;;
        esac
    done
    return 1
}
