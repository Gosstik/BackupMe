#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

################################################################################

fn_request_sudo() {
  if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
  fi
}
export -f fn_request_sudo

################################################################################

fn_import_env_variables() {
  set -o allexport

  local FILE_PATH="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.env"
  if [ -e "${FILE_PATH}" ]; then
    source "${FILE_PATH}" set
  fi

  local FILE_PATH="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.local.env"
  if [ -e "${FILE_PATH}" ]; then
    source "${FILE_PATH}" set
  fi

  set +o allexport
}
export -f fn_import_env_variables

################################################################################

# Explanation: https://stackoverflow.com/a/731634/16704057
# Usage: file_mutex /var/run/myscript.lock || { echo "Already running." >&2; exit 1; }
fn_file_mutex() {
    local FILE="$1" PID PIDS KILL_OTHER=""

    exec 9>>"${FILE}"
    { PIDS=$(fuser -f "${FILE}"); } 2>&- 9>&-
    for PID in ${PIDS}; do
        [[ "${PID}" = "$$" ]] && continue

        if [ -n "${KILL_OTHER}" ]; then
          # Just killing other process
          kill -9 "${PID}"
          continue
        fi

        echo "Process is already running: $0 (PID=${PID})"
        if [ -n "${ENV_IS_CRON_JOB:-}" ] && [ "${ENV_IS_CRON_JOB}" = "TRUE" ]; then
          echo "Running from cron, so killing all active processes by default"
          kill -9 "${PID}"
          continue
        fi

        read -r -n 1 -p "Kill other? (print 'y' or smth else to reject): "
        if [ -n "${REPLY}" ] && [ "${REPLY}" = "y" ]; then
          echo -e "\nKilling all active processes"
          kill -9 "${PID}"
          continue
        else
          echo -e "\nReturn without killing"
        fi

        exec 9>&- # close 9 FD
        return 1 # Already locked by a PID.
    done
}
export -f fn_file_mutex

################################################################################

fn_acquire_file_mutex() {
  local FILE_NAME="$1" BASH_SOURCE_ABS BASH_SOURCE_DIR FILE
  BASH_SOURCE_ABS=$(realpath "${BASH_SOURCE[0]}")
  BASH_SOURCE_DIR=$(dirname "${BASH_SOURCE_ABS}")
  FILE="${BASH_SOURCE_DIR}/.lock/${FILE_NAME}"

  fn_file_mutex "${FILE}" || { exit 2; }
  echo $$ > "${FILE}"
}
export -f fn_acquire_file_mutex

################################################################################

fn_get_src_dir_with_checks() {
  #SRC_DIR="/home/gostik"
  local SRC_DIR="$1"

  if [ -z "${SRC_DIR}" ]; then
    echo "SRC_DIR is not provided, exiting"
    exit 2
  fi

  if [ ! -e "${SRC_DIR}" ]; then
    echo "SRC_DIR=${SRC_DIR} does not exist, exiting"
    exit 2
  fi

  echo "${SRC_DIR}"
}
export -f fn_get_src_dir_with_checks

################################################################################

fn_remove_log_and_backup_dir() {
  # Args
  local DIR_TO_REMOVE="$1" LOG_NAME LOG

  # remove log
  LOG_NAME=$(basename "${DIR_TO_REMOVE}")
  LOG_NAME="${LOG_NAME//_INCOMPLETE/}.log"
  LOG="$(dirname "${DIR_TO_REMOVE}")/logs/${LOG_NAME}"
  echo "removing log: ${LOG}"
  rm -f "${LOG}"

  # remove log command
  RSYNC_LOG_COMMAND="${DIR_TO_REMOVE}_rsync_cmd.log"
  echo "removing rsync command log: ${LOG}"
  rm -f "${RSYNC_LOG_COMMAND}"

  # remove dir
  echo "removing dir: ${DIR_TO_REMOVE}"
  rm -rf "${DIR_TO_REMOVE}"
}
export -f fn_remove_log_and_backup_dir

################################################################################

fn_remove_extra_home_backups() {
  # "${ENV_BACKUPS_STORAGE_DIR}/${SRC_SLASHED_NAME}"
  ALL_HOME_BACKUPS_DIR="$1"
  echo "Searching for extra Home backups to remove..."

  DEST_DIRS=$(find "${ALL_HOME_BACKUPS_DIR}/" -maxdepth 1 -type d -name "????-??-??_??-??-??" | sort -r)
  DEST_DIRS_COUNT=$(echo "${DEST_DIRS}" | wc -l)
  echo "Found ${DEST_DIRS_COUNT}. It is required to storage ${ENV_MAX_DEST_DIRS_COUNT}"

  if [ "${DEST_DIRS_COUNT}" -gt "${ENV_MAX_DEST_DIRS_COUNT}" ]; then
    echo "Removing extra Home backups..."

    COUNT_LEFT=${ENV_MAX_DEST_DIRS_COUNT}
    if [ "${ENV_DELETE_OLDEST_BACKUP}" = "FALSE" ]; then
      DEST_DIRS="${DEST_DIRS%$'\n'*}" # cut the oldest one
      ((COUNT_LEFT--))
    fi
    DIRS_TO_REMOVE=$(echo "${DEST_DIRS}" | sed "1,${COUNT_LEFT}d")

    echo "${DIRS_TO_REMOVE}" |
    while read -r DIR_TO_REMOVE; do
      fn_remove_log_and_backup_dir "${DIR_TO_REMOVE}"
    done

    echo "Extra Home backups removed successfully!"
  else
    echo "No need to remove, returning"
  fi
}
export -f fn_remove_extra_home_backups

################################################################################

fn_get_home_dest_dirs() {
  SRC_DIR="$1"

  SRC_SLASHED_NAME="${SRC_DIR//\//_}"
  ALL_HOME_BACKUPS_DIR="${ENV_BACKUPS_STORAGE_DIR}/${SRC_SLASHED_NAME}"
  BACKUP_DIRS=$(find "${ALL_HOME_BACKUPS_DIR}/" -maxdepth 1 -type d -name "????-??-??_??-??-??" | sort -r)

  echo "${BACKUP_DIRS}"
}
export -f fn_get_home_dest_dirs

################################################################################

fn_get_timeshift_dirs() {
  BACKUP_DIRS=$(find "${ENV_TIMESHIFT_BACKUP_DIR}" -maxdepth 1 -type d -name "????-??-??_??-??-??")
  echo "${BACKUP_DIRS}"
}

################################################################################

fn_remove_extra_timeshift_backups() {
    echo "Searching for extra TimeShift backups to remove..."

    BACKUP_DIRS=$(fn_get_timeshift_dirs | sort -r)
    DIRS_COUNT=$(echo "${BACKUP_DIRS}" | wc -l)
    echo "Found ${DIRS_COUNT}. It is required to storage ${ENV_TIMESHIFT_MAX_BACKUP_DIRS}"

    if [ "${DIRS_COUNT}" -gt "${ENV_TIMESHIFT_MAX_BACKUP_DIRS}" ]; then
      echo "Removing extra TimeShift backups..."

      COUNT_LEFT=${ENV_TIMESHIFT_MAX_BACKUP_DIRS}
      if [ "${ENV_DELETE_OLDEST_BACKUP}" = "FALSE" ]; then
        BACKUP_DIRS="${BACKUP_DIRS%$'\n'*}" # cut the oldest one
        ((COUNT_LEFT--))
      fi
      DIRS_TO_REMOVE=$(echo "${BACKUP_DIRS}" | sed "1,${COUNT_LEFT}d")

      echo "${DIRS_TO_REMOVE}" |
      while read -r DIR_TO_REMOVE; do
        CMD="timeshift --delete --snapshot $(basename "${DIR_TO_REMOVE}")"
        echo "Executing '${CMD}'"
        ${CMD}
      done

      echo "Old TimeShift backups removed successfully!"

    else
      echo "No need to remove, returning"
    fi
}
export -f fn_remove_extra_timeshift_backups

################################################################################

fn_get_all_incomplete_dirs() {
  for SRC_DIR in ${ENV_DIRS_TO_BACKUP}; do
#    SRC_DIR="/home/gostik"
    SRC_SLASHED_NAME="${SRC_DIR//\//_}"
    ALL_HOME_BACKUPS_DIR="${ENV_BACKUPS_STORAGE_DIR}/${SRC_SLASHED_NAME}"
    INCOMPLETE_DIRS+=$(find "${ALL_HOME_BACKUPS_DIR}/" -maxdepth 1 -type d -name "????-??-??_??-??-??_INCOMPLETE" | sort -r)
    if [ -n "${INCOMPLETE_DIRS}" ]; then
      INCOMPLETE_DIRS+=$'\n'
    fi
  done
  if [ -n "${INCOMPLETE_DIRS}" ]; then
    INCOMPLETE_DIRS="${INCOMPLETE_DIRS::-1}"
  fi
  echo "${INCOMPLETE_DIRS}"
}
export -f fn_get_all_incomplete_dirs

################################################################################

fn_remove_incomplete_backups() {
  INCOMPLETE_DIRS="$1"

  echo "Removing incomplete backups..."
  if [ -z "${INCOMPLETE_DIRS}" ]; then
    echo "No incomplete backups passed, return from fn_remove_incomplete_backups()"
    return
  fi

  # Can be replaced by 'for ... in ...', but is more general way
  echo "${INCOMPLETE_DIRS}" |
  while read -r DIR_TO_REMOVE; do
    fn_remove_log_and_backup_dir "${DIR_TO_REMOVE}"
  done

  echo "Incomplete backups removed successfully!"
}
export -f fn_remove_incomplete_backups

################################################################################

fn_remove_incomplete_backups_without_arg() {
  INCOMPLETE_DIRS=$(fn_get_all_incomplete_dirs)
  if [ -z "${INCOMPLETE_DIRS}" ]; then
    echo "There are no incomplete backups, return"
  fi
  fn_remove_incomplete_backups "${INCOMPLETE_DIRS}"
}
export -f fn_remove_incomplete_backups_without_arg

################################################################################

fn_remove_old_cron_logs() {
  CRON_LOG_DIR="$1"

  echo -e "\nStarting fn_remove_old_cron_logs() with CRON_LOG_DIR='${CRON_LOG_DIR}'"

  LOG_FILES=$(find "${CRON_LOG_DIR}" -maxdepth 1 -type f -name "????-??-??_??-??-??.log" | sort)
  CUT_LOG_FILES="${LOG_FILES//.log/}"
  if [ -z "${CUT_LOG_FILES:-}" ]; then
    echo "No old logs found"
  fi

  for CUT_LOG_FILE in ${CUT_LOG_FILES}; do
    # Extract date from dir name
    FILE_DATE=$(fn_get_date_from_dirpath "${CUT_LOG_FILE}")
    FILE_TIME=$(( "$(date +%s)" - "$(date -d "${FILE_DATE}" +%s)" ))
    DATE_DIFF="$(fn_date_diff "$(date +%s)" "$(date -d "${FILE_DATE}" +%s)")"

    EXPIRATION_TIME=$(fn_parse_to_sec "${ENV_CRON_LOG_EXPIRATION_TIME}")

    if [ "${FILE_TIME}" -gt "${EXPIRATION_TIME}" ]; then
      # Log is too old
      echo "removing '${CUT_LOG_FILE}.log' (created ${DATE_DIFF} ago)"
      rm "${CUT_LOG_FILE}.log"
    fi
  done

  echo -e "Finished fn_remove_old_cron_logs()"
}

################################################################################

# Functions of backup

fn_power_off() {
  echo "Power Off"
  poweroff
}
export -f fn_power_off

fn_backup_home() {
  echo "Creating Home backup... (fn_backup_home)"

  echo "BASH_SOURCE[0]=${BASH_SOURCE[0]}"
  SCRIPT_FOLDER=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
  for SRC_DIR in ${ENV_DIRS_TO_BACKUP}; do
    # Creating backup
    source "${SCRIPT_FOLDER}/backup_creator.sh" "${SRC_DIR}"

    # Removing extra backups
    SRC_SLASHED_NAME="${SRC_DIR//\//_}"
    fn_remove_extra_home_backups "${ENV_BACKUPS_STORAGE_DIR}/${SRC_SLASHED_NAME}"
  done

  echo "Home backup created successfully! (fn_backup_home)"
}
export -f fn_backup_home

# With timeshift
fn_backup_system() {
  echo "Creating TimeShift backup... (fn_backup_system)"

  # Create new backup
  TIMESHIFT_COMMENT=$(date +"%d %b, %Y")
  # '--tags O' does not work, but it is so by default
  timeshift --rsync --create --comments "${TIMESHIFT_COMMENT}" --yes
  fn_remove_extra_timeshift_backups

  echo "TimeShift backup created successfully! (fn_backup_system)"
}
export -f fn_backup_system

fn_full_backup() {
  echo "Creating Full backup... (fn_full_backup)"
  fn_backup_system
  fn_backup_home
  echo "Full backup created successfully! (fn_full_backup)"
}
export -f fn_full_backup

################################################################################

# Power On util

fn_disable_sleep() {
  echo "fn_disable_sleep()"
#  systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
#  trap 'systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target' INT QUIT TERM EXIT USR2
}
export -f fn_disable_sleep

fn_enable_sleep() {
   echo "fn_enable_sleep()"
#   kill -SIGUSR2 $$
}
export -f fn_enable_sleep

################################################################################

fn_close_terminal_with_delay() {
  echo -ne "\nTerminal will be closed in..."
  for i in {8..1};do echo -n " $i" && sleep 1; done
}
export -f fn_close_terminal_with_delay

################################################################################

fn_close_terminal_on_enter() {
  read -r -n 1 -p "Press 'Enter' to exit... "
}
export -f fn_close_terminal_on_enter

################################################################################

fn_create_delayed_exit() {
  if [ -n "$(trap)" ]; then
    echo "trap is already used, cannot use it in fn_create_delayed_exit()"
    return
  fi
  trap 'fn_close_terminal_with_delay' EXIT USR2
}
export -f fn_create_delayed_exit

################################################################################

fn_wait_or_exit() {
  if [ -n "${ENV_IS_CRON_JOB:-}" ] && [ "${ENV_IS_CRON_JOB}" = "TRUE" ]; then
    echo "Cron is running, skipping 'enter' and exit"
  else
    read -r -n 1 -p "Press 'Enter' to exit... "
  fi
}
export -f fn_wait_or_exit

cleanup () {
  TYPE="$1"
  CONTENT="$2"

  su -c 'xhost -si:localuser:root' "${ENV_ROOT_USER}" # disable run GUI as root

  if [ "${TYPE}" = "SIG" ]; then
    echo -e "\nAborted by $CONTENT"
    fn_wait_or_exit
  else
    # TYPE="EXIT"
    EXIT_STATUS="${CONTENT}"
    if [ "${EXIT_STATUS}" -ne 0 ]; then
      echo -e "\nFailure occurred, EXIT_STATUS=${EXIT_STATUS}"
      fn_wait_or_exit
    else
      echo -e "\nExited successfully!"
      if [ -n "${ENV_ALWAYS_WAIT_ENTER_AFTER_SCRIPT:-}" ] && [ "${ENV_ALWAYS_WAIT_ENTER_AFTER_SCRIPT}" = "TRUE" ]; then
        fn_wait_or_exit
      fi
    fi
  fi
}
export -f cleanup

fn_wait_for_display_becomes_available() {
  local DISPLAY_IS_READY=""
  local PAUSE_TIME=3
  local CYCLES_COUNT=0
  set +o errexit
  while [ -z "${DISPLAY_IS_READY}" ]; do
    su -c 'xhost +si:localuser:root' "${ENV_ROOT_USER}" >&/dev/null
    if [ "$?" -eq 0 ]; then
      echo "DISPLAY became available, wait 3 seconds more and continue"
      sleep 3
      break
    else
      echo "DISPLAY=${DISPLAY} is unavailable, waiting..."
      sleep "${PAUSE_TIME}"
      (( CYCLES_COUNT += 1 ))
      if [ "${CYCLES_COUNT}" -eq 100 ]; then
        echo "Stop waiting, exiting"
        exit 2
      fi
    fi
  done
  set -o errexit
}

fn_exit_on_enter() {
  if [ -n "${ENV_IS_CRON_JOB:-}" ] && [ "${ENV_IS_CRON_JOB}" = "TRUE" ]; then
    fn_wait_for_display_becomes_available
  fi

  su -c 'xhost +si:localuser:root' "${ENV_ROOT_USER}" # enable run GUI as root

#  trap -p SIGINT  # only show traps for SIGINT
  if [ -n "$(trap)" ]; then
    echo "trap is already used, cannot use it in fn_exit_on_enter()"
    return
  fi
  trap 'EXIT_STATUS=$?; cleanup EXIT ${EXIT_STATUS}; exit ${EXIT_STATUS}' EXIT
  trap 'trap - HUP; cleanup SIG SIGHUP; kill -HUP $$' HUP
  trap 'trap - INT; cleanup SIG SIGINT; kill -INT $$' INT
  trap 'trap - TERM; cleanup SIG SIGTERM; kill -TERM $$' TERM
  trap 'trap - QUIT; cleanup SIG SIGQUIT; kill -QUIT $$' QUIT
}
export -f fn_exit_on_enter

################################################################################
