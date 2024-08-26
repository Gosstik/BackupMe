#!/bin/bash

# Check if there are INCOMPLETE backups or last backup is too old

################################################################################

# Sourcing utils

BASH_SOURCE_ABS=$(realpath "${BASH_SOURCE[0]}")
BASH_SOURCE_NAME=$(basename "${BASH_SOURCE_ABS}")
BASH_SOURCE_DIR=$(dirname "${BASH_SOURCE_ABS}")
PROJECT_DIR=$(dirname "${BASH_SOURCE_DIR}")
source "${PROJECT_DIR}/util.sh"

fn_request_sudo
fn_acquire_file_mutex "${BASH_SOURCE_NAME}.lock"
fn_import_env_variables

################################################################################

# Debug

#fn_create_delayed_exit
fn_exit_on_enter

################################################################################

# Main logic

source "${PROJECT_DIR}/gui_util.sh"

MSG="\\n\\t\\t\\t\\t\\t\\t\\t\\t\\t\\t\\t\\t<span size='x-large'>\
    <b>${ENV_APP_TITLE} Menu</b></span>"
echo "Starting fn_draw_menu_window()..."
YAD_RES=$(fn_draw_menu_window "${MSG}" 1 2 3 "Cancel" "Menu")
echo "Finished fn_draw_menu_window()"
echo "YAD_RES='${YAD_RES}'"

case "${YAD_RES}" in
  0) fn_remove_incomplete_backups_without_arg ;;
  2) fn_disable_sleep; fn_full_backup; fn_enable_sleep ;;
  1) echo "Cancel button" ;;
  252) echo "Window closed, exiting" ;;
  *) echo "Unknown command, exiting" ;;
esac
