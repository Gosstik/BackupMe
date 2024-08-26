#!/bin/bash

# Clean logs from cron_logs.d

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
#fn_acquire_file_mutex "${BASH_SOURCE_NAME}.lock"
fn_import_env_variables
echo "variables were imported"

################################################################################

# Debug

#fn_create_delayed_exit
fn_exit_on_enter # required to run GUI as root
echo "fn_exit_on_enter finished"

################################################################################

fn_remove_old_cron_logs() {
  CRON_LOG_DIR="$1"

  echo -e "\nStarting fn_remove_old_cron_logs() with CRON_LOG_DIR='${CRON_LOG_DIR}'"

  LOG_FILES=$(find "${CRON_LOG_DIR}" -maxdepth 1 -type f -name "????-??-??_??-??-??.log" | sort)
  CUT_LOG_FILES="${LOG_FILES//.log/}"
  #echo "${LOG_FILES}"

  for CUT_LOG_FILE in ${CUT_LOG_FILES}; do
    # Extract date from dir name
    FILE_DATE=$(fn_get_date_from_dirpath "${CUT_LOG_FILE}")
    FILE_TIME=$(( "$(date +%s)" - "$(date -d "${FILE_DATE}" +%s)" ))
    DATE_DIFF="$(fn_date_diff "$(date +%s)" "$(date -d "${FILE_DATE}" +%s)")"

    EXPIRATION_TIME=$(fn_parse_to_sec "${ENV_CRON_LOG_EXPIRATION_TIME}")

  #  echo "FILE_TIME=${FILE_TIME}"
  #  echo "EXPIRATION_TIME=${EXPIRATION_TIME}"
    if [ "${FILE_TIME}" -gt "${EXPIRATION_TIME}" ]; then
      # Log is too old
      echo "removing '${CUT_LOG_FILE}.log' (created ${DATE_DIFF} ago)"
      rm "${CUT_LOG_FILE}.log"
    fi
  done

  echo -e "Finished fn_remove_old_cron_logs()"
}

################################################################################

# Main logic

echo "Main logic started"

echo "Current ENV_CRON_LOG_EXPIRATION_TIME='${ENV_CRON_LOG_EXPIRATION_TIME}'"
fn_remove_old_cron_logs "${PROJECT_DIR}/cron_logs.d"
fn_remove_old_cron_logs "${PROJECT_DIR}/cron_logs.d/clear_log_script"

echo -e "\nMain logic finished"
