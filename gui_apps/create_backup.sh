#!/bin/bash

# Creates backup, then turns off the PC

################################################################################

# Sourcing utils

BASH_SOURCE_ABS=$(realpath "${BASH_SOURCE[0]}")
BASH_SOURCE_NAME=$(basename "${BASH_SOURCE_ABS}")
BASH_SOURCE_DIR=$(dirname "${BASH_SOURCE_ABS}")
PROJECT_DIR=$(dirname "${BASH_SOURCE_DIR}")
source "${PROJECT_DIR}/util.sh"
source "${PROJECT_DIR}/gui_util.sh"

fn_request_sudo
#fn_acquire_file_mutex "${BASH_SOURCE_NAME}.lock"
fn_import_env_variables

################################################################################

# Debug

#fn_create_delayed_exit
fn_exit_on_enter

################################################################################

# GUI

# Produce YAD_RES and EXIT_STATUS
YAD_RES=$(fn_draw_create_backup_window)
echo "YAD_RES='${YAD_RES}'"
YAD_EXIT_STATUS="${YAD_RES##*$'\n'}"
echo "YAD_EXIT_STATUS='${YAD_EXIT_STATUS}'"
YAD_RES="${YAD_RES%$'\n'*}" # cut last line

if [ "${YAD_EXIT_STATUS}" -ne 0 ]; then
  echo "Window was closed (exit status ${YAD_EXIT_STATUS}), exiting"
  exit 0
fi

POWER_OFF_CHECKBOX=$(echo "${YAD_RES%%$'\n'*}" | awk -F'|' '{ print $1 }')
echo "POWER_OFF_CHECKBOX='${POWER_OFF_CHECKBOX}'"

LINES_COUNT=$(echo "${YAD_RES}" | wc -l)
echo "LINES_COUNT='${LINES_COUNT}'"
if [ ${LINES_COUNT} -eq 1 ]; then
  echo "Option for backup was not chosen"

  if [ "${POWER_OFF_CHECKBOX}" = "TRUE" ]; then
    echo "Power Off was marked, so do it"
    fn_power_off && exit 0
  fi

  echo "Power Off is not marked, exiting"
  exit 0
fi

# There are two lines in YAD_RES, backup option is in the second
SECOND_LINE="${YAD_RES##*$'\n'}"
echo "SECOND_LINE='${SECOND_LINE}'"
CHOSEN_OPTION=$(echo "${SECOND_LINE}" | awk -F'|' '{ print $1 }')
FUNCTION_TO_CALL=$(echo "${SECOND_LINE}" | awk -F'|' '{ print $2 }')

echo "'${CHOSEN_OPTION}' was chosen"
fn_disable_sleep
"${FUNCTION_TO_CALL}"
fn_enable_sleep

################################################################################

if [ "${POWER_OFF_CHECKBOX}" = "TRUE" ]; then
  echo "Power Off was marked, so do it"
  fn_power_off && exit 0
fi
