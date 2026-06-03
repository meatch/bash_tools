# Noun Project volume preservation
# Setup: cp noun-project.sample.sh noun-project.sh
# Then source it from config.sh:
#   source "$(dirname "$0")/config/noun-project.sh"
#   PRESERVE_VOLUMES=("${NOUN_PROJECT_VOLUMES[@]}")

NOUN_PROJECT_VOLUMES=(
    # "noun_mysql"
    # "noun_search"
)
