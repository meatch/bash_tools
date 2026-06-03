# Shared config — sourced at shell startup for all tools.
# Setup: cp config.sample.sh config.sh
# config.sh is gitignored — each developer maintains their own.
#
# Optional: source per-project arrays from config/ for organization
# source "$BASH_TOOLS_ROOT/config/noun-project.sh"

# Docker: volumes listed here are preserved during docker prune operations.
# Glob patterns are supported: *-wp-content, project-*, app-?-db
PRESERVE_VOLUMES=(
    # "noun_mysql"
    # "noun_search"
    # "*-wp-content"
    # "*-mysql-data"
)
