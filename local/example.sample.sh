# local/example.sample.sh
#
# Scripts in local/ are gitignored and auto-sourced by init.sh after all
# shared scripts load, so you have access to everything already defined.
#
# Copy this file (without .sample) to get started:
#   cp local/example.sample.sh local/personal.sh
#
# Any *.sh file you drop in local/ is sourced automatically on shell init.
# *.sample.sh files are committed to the repo as documentation; all other
# *.sh files here are ignored by git.

# Example: a work-specific alias
# alias work-vpn='sudo openconnect vpn.example.com'

# Example: override a default from the shared scripts
# export DOCKER_DEFAULT_PLATFORM=linux/amd64
