#!/bin/bash
#
# cron on-boot script

# Check whether there are INCOMPLETE backups or last backups are too old

################################################################################

# Sourcing utils

BASH_SOURCE_ABS=$(realpath "${BASH_SOURCE[0]}")
BASH_SOURCE_NAME=$(basename "${BASH_SOURCE_ABS}")
BASH_SOURCE_DIR=$(dirname "${BASH_SOURCE_ABS}")
PROJECT_DIR=$(dirname "${BASH_SOURCE_DIR}")
echo "${BASH_SOURCE_ABS} started"

source "${PROJECT_DIR}/util.sh"
source "${PROJECT_DIR}/gui_util.sh"
echo "utils were sourced"

fn_request_sudo
fn_acquire_file_mutex "${BASH_SOURCE_NAME}.lock"
fn_import_env_variables
echo "variables were imported"

################################################################################

# Debug

#fn_create_delayed_exit
fn_exit_on_enter # required to run GUI as root
echo "fn_exit_on_enter() finished"

################################################################################

# GUI functions

fn_check_home_incomplete_backup() {
  echo -e "\nStarting fn_check_home_incomplete_backup()..."

  INCOMPLETE_DIRS=$(fn_get_all_incomplete_dirs)

  if [ -n "${INCOMPLETE_DIRS}" ]; then
    # Some INCOMPLETE dirs where found
    MSG="\\n\\t\\t\\t\\t\\t\\t\\t\\t\\t<span size='x-large'><b>Incomplete Home backups</b> were found.</span>"
    YAD_RES=$(fn_draw_menu_window "${MSG}" 2 3 1 "Just remove incomplete" "Home")
    echo "YAD_RES='${YAD_RES}'"

    case "${YAD_RES}" in
      0) fn_disable_sleep; fn_backup_home; fn_enable_sleep ;;
      2) fn_disable_sleep; fn_full_backup; fn_enable_sleep ;;
      1) echo "Cancel button" ;;
      252) echo "Window closed, exiting fn_check_home_incomplete_backup()" && return ;;
      *) echo "Unknown command, exiting fn_check_home_incomplete_backup()" && return ;;
    esac

    fn_remove_incomplete_backups "${INCOMPLETE_DIRS}"
  fi

  echo "fn_check_home_incomplete_backup() finished successfully!"
}

################################################################################

fn_call_backup_home() {
  fn_disable_sleep
  fn_backup_home
#  gnome-terminal --wait -- /bin/bash -c 'fn_backup_home; fn_close_terminal_on_enter'
#  if [ -n "${ENV_IS_CRON_JOB:-}" ] && [ "${ENV_IS_CRON_JOB}" = "TRUE" ]; then
#    export -f fn_full_backup
#    gnome-terminal -- /ban/bash -c 'fn_backup_home; sleep 5'
#  else
#    fn_backup_home
#  fi
  fn_enable_sleep
}

fn_home_fresh_backup_gui_handler() {
  MSG="$1"

  YAD_RES=$(fn_draw_menu_window "${MSG}" 1 2 3 "Close" "Home")
  echo "YAD_RES='${YAD_RES}'"

  case "${YAD_RES}" in
    0) echo "OK pressed" ;;
    252) echo "Window closed" && return ;;
    *) echo "Unknown command while closing window" && return ;;
  esac

#  case "${YAD_RES}" in
#    0) fn_call_backup_home ;;
#    2) fn_disable_sleep; fn_full_backup; fn_enable_sleep ;;
#    1) echo "Close button" ;;
#    252) echo "Window closed" && return ;;
#    *) echo "Unknown command while closing window" && return ;;
#  esac
}

fn_check_home_fresh_backup() {
  echo -e "\nStarting fn_check_home_fresh_backup()..."

  # ENV_DIRS_TO_BACKUP is in .env
  for SRC_DIR in ${ENV_DIRS_TO_BACKUP}; do
#    SRC_DIR="/home/gostik"
    DEST_DIRS=$(fn_get_home_dest_dirs "${SRC_DIR}")
    if [ -z "${DEST_DIRS}" ]; then
      # There are no backups of SRC_DIR
      MSG="\\n\\t\\t\\t\\t\\t<span size='x-large'>\
          <b>There are no Home backups</b> for '${SRC_DIR}'.</span>"

      fn_home_fresh_backup_gui_handler "${MSG}"
      echo "continue cycle"
      continue
    fi

    # Extract date from dir name
    MOST_FRESH_DIR=$(echo "${DEST_DIRS}" | sed -n "1p")
    DIR_DATE=$(fn_get_date_from_dirpath "${MOST_FRESH_DIR}")
    DIR_TIME=$(( "$(date +%s)" - "$(date -d "${DIR_DATE}" +%s)" ))
    DATE_DIFF="$(fn_date_diff "$(date +%s)" "$(date -d "${DIR_DATE}" +%s)")"

    EXPIRATION_TIME=$(fn_parse_to_sec "${ENV_HOME_BACKUP_FRESH_DURATION}")

    if [ "${DIR_TIME}" -gt "${EXPIRATION_TIME}" ]; then
      # Backup is too old
      MSG="\\n\\t\\t\\t\\t<span size='x-large'>\
              Last <b>Home</b> backup of <b>${SRC_DIR}</b> was <b>${DATE_DIFF} ago</b> \
              \\n\\t\\t\\t\\t\\t\\t\\t\\t\\t\\t<b>Required</b> to do it <b>every ${ENV_HOME_BACKUP_FRESH_DURATION}</b></span>"

      fn_home_fresh_backup_gui_handler "${MSG}"
      echo "continue cycle to check other SRC_DIR"
      continue
    fi
  done

  echo "fn_check_home_fresh_backup() finished successfully!"
}

################################################################################

fn_call_backup_system() {
  fn_disable_sleep
  fn_backup_system
#  if [ -n "${ENV_IS_CRON_JOB:-}" ] && [ "${ENV_IS_CRON_JOB}" = "TRUE" ]; then
#    export -f fn_backup_system
#    gnome-terminal -- /ban/bash -c 'fn_backup_system; sleep 5'
#  else
#    fn_backup_system
#  fi
  fn_enable_sleep
}

fn_timeshift_fresh_backup_gui_handler() {
  YAD_RES=$(fn_draw_menu_window "${MSG}" 2 1 3 "Close" "TimeShift")
  echo "YAD_RES='${YAD_RES}'"

  case "${YAD_RES}" in
    0) echo "OK pressed" && return;;
    252) echo "Window closed" && return ;;
    *) echo "Unknown command while closing window" && return ;;
  esac

#  case "${YAD_RES}" in
#    0) fn_call_backup_system ;;
#    2) fn_disable_sleep; fn_full_backup; fn_enable_sleep ;;
#    1) echo "Close button" ;;
#    252) echo "Window closed" && return ;;
#    *) echo "Unknown command while closing window" && return ;;
#  esac
}

fn_check_timeshift_fresh_backup() {
  echo -e "\nStarting fn_check_timeshift_fresh_backup()..."

  DEST_DIRS=$(fn_get_timeshift_dirs | sort -r)
  if [ -z "${DEST_DIRS}" ]; then
    # There are no backups of system
    MSG="\\n\\t\\t\\t\\t\\t\\t\\t\\t\\t<span size='x-large'>\
        <b>There are no TimeShift backups</b>.</span>"

    fn_timeshift_fresh_backup_gui_handler "${MSG}"
    echo "fn_check_timeshift_fresh_backup() finished successfully!"
    return
  fi

  # Extract date from dir name
  MOST_FRESH_DIR=$(echo "${DEST_DIRS}" | sed -n "1p")
  DIR_DATE=$(fn_get_date_from_dirpath "${MOST_FRESH_DIR}")
  DIR_TIME=$(( "$(date +%s)" - "$(date -d "${DIR_DATE}" +%s)" ))
  DATE_DIFF="$(fn_date_diff "$(date +%s)" "$(date -d "${DIR_DATE}" +%s)")"

  EXPIRATION_TIME=$(fn_parse_to_sec "${ENV_TIMESHIFT_BACKUP_FRESH_DURATION}")

  if [ "${DIR_TIME}" -gt "${EXPIRATION_TIME}" ]; then
    # Last backup is too old
    MSG="\\n\\t\\t\\t\\t\\t\\t<span size='x-large'>\
        Last <b>TimeShift</b> backup was <b>${DATE_DIFF} ago</b> \
        \\n\\t\\t\\t\\t\\t\\t\\t\\t\\t\\t<b>Required</b> to do it <b>every ${ENV_TIMESHIFT_BACKUP_FRESH_DURATION}</b></span>"

    fn_timeshift_fresh_backup_gui_handler "${MSG}"
  fi

  echo "fn_check_timeshift_fresh_backup() finished successfully!"
}

################################################################################

# Main logic

echo "Main logic started"
fn_remove_old_cron_logs "${ENV_CRON_LOGS_DIR}"
fn_check_home_incomplete_backup
fn_check_home_fresh_backup
fn_check_timeshift_fresh_backup
echo -e "\nMain logic finished"
