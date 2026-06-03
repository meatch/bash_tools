# Docker volume preservation config
# Setup: cp config.sample.sh config.sh
# Then edit config.sh — it is gitignored, so each developer maintains their own.
#
# Optional: source per-project arrays from config/ (see config/noun-project.sample.sh)
# source "$(dirname "$0")/config/noun-project.sh"

# Volumes listed here are skipped during docker prune operations.
# Glob patterns are supported: *-wp-content, project-*, app-?-db
PRESERVE_VOLUMES=(
    # "noun_mysql"
    # "noun_search"
    # "*-wp-content"
    # "*-mysql-data"
)
