#!/bin/bash

################################################################################

# Sourcing utils

BASH_SOURCE_ABS=$(realpath "${BASH_SOURCE[0]}")
BASH_SOURCE_NAME=$(basename "${BASH_SOURCE_ABS}")
BASH_SOURCE_DIR=$(dirname "${BASH_SOURCE_ABS}")
PROJECT_DIR="${BASH_SOURCE_DIR}"
source "${PROJECT_DIR}/util.sh"

fn_import_env_variables

# https://unix.stackexchange.com/questions/230238/x-applications-warn-couldnt-connect-to-accessibility-bus-on-stderr
export NO_AT_BRIDGE=1

################################################################################
# Dates

fn_get_date_from_dirpath() {
  local DIR_PATH="${1}" DIR_NAME FIRST SECOND
  DIR_NAME=$(basename "${DIR_PATH}")

  FIRST=${DIR_NAME%_*}
  SECOND=${DIR_NAME#*_}
  echo "${FIRST} ${SECOND//-/:}"
#  DATE=$(date +"%d %b, %Y" -d"${DATE}")
}
export -f fn_get_date_from_dirpath

fn_get_date_from_incomplete_path() {
  local BACKUP_PATH="${1}" DATE FIRST SECOND
  DATE=$(basename "${BACKUP_PATH}")
  DATE="${DATE//"_INCOMPLETE"/}"
  FIRST=${DATE%_*}
  SECOND=${DATE#*_}
  echo "${FIRST} ${SECOND//-/:}"
}
export -f fn_get_date_from_incomplete_path

export SEC_IN_DAY=$(( 60*60*24 ))
export SEC_IN_HOUR=$(( 60*60 ))
export SEC_IN_MIN=$(( 60 ))

fn_date_diff() {
  local FIRST="$1" SECOND="$2" DAYS HOURS MINS SECONDS # all in seconds
  DAYS=$(( (FIRST - SECOND ) / SEC_IN_DAY ))
  if [ ${DAYS} -gt 0 ]; then
    echo "${DAYS} days"
    return
  fi

  HOURS=$(( (FIRST - SECOND ) / SEC_IN_HOUR ))
  if [ ${HOURS} -gt 0 ]; then
    echo "${HOURS} hours"
    return
  fi

  MINS=$(( (FIRST - SECOND ) / SEC_IN_MIN ))
  if [ ${MINS} -gt 0 ]; then
    echo "${MINS} minutes"
    return
  fi

  echo "$(( FIRST - SECOND )) seconds"
}
export -f fn_date_diff

fn_parse_to_sec() {
#  TIME="2 secs"; TIME="40 mins"
  local TIME="$1" DAYS HOURS MINS SECONDS # all in seconds

  TYPE="${TIME#* }"
  TIME_VAL="${TIME% *}"

  case "${TYPE}" in
    "sec"|"secs"|"second"|"seconds") echo "${TIME_VAL}" ;;
    "min"|"mins"|"minute"|"minutes") ((TIME_VAL *= SEC_IN_MIN)); echo "${TIME_VAL}" ;;
    "hour"|"hours") ((TIME_VAL *= SEC_IN_HOUR)); echo "${TIME_VAL}" ;;
    "day"|"days") ((TIME_VAL *= SEC_IN_DAY)); echo "${TIME_VAL}" ;;
    *) echo "error in fn_parse_to_sec(): unable to recognize time: '${TIME}'"
  esac
}
export -f fn_parse_to_sec

################################################################################

fn_get_dir_columns() {
  local GET_BACKUP_DATE_FUNCTION="$1" FIND_PATTERN="$2"

  DEST_DIRS=""
  for SRC_DIR in ${ENV_DIRS_TO_BACKUP}; do
#    SRC_DIR="/home/gostik"
    SRC_SLASHED_NAME="${SRC_DIR//\//_}"
    BACKUP_DIR="${ENV_BACKUPS_STORAGE_DIR}/${SRC_SLASHED_NAME}"
    CUR_RES=$(find "${BACKUP_DIR}/" -maxdepth 1 -type d -name "${FIND_PATTERN}" | sort -r)

    NEW_RES=""
    for RES in ${CUR_RES}; do
      DATE=$("${GET_BACKUP_DATE_FUNCTION}" "${RES}")
      DATE_DIFF="$(fn_date_diff "$(date +%s)" "$(date -d "${DATE}" +%s)") ago"

      NEW_RES+="${DATE_DIFF}"$'\n'
      NEW_RES+="${SRC_DIR}"$'\n'
      NEW_RES+="${RES}"$'\n'
    done
    DEST_DIRS+="${NEW_RES}"
  done
  if [ -n "${DEST_DIRS}" ]; then
    DEST_DIRS="${DEST_DIRS::-1}"
  fi
  echo -n "${DEST_DIRS}"
}
export -f fn_get_dir_columns

################################################################################

fn_get_timeshift_columns() {
  CUR_RES=$(fn_get_timeshift_dirs | sort -r)
  NEW_RES=""
  for RES in ${CUR_RES}; do
    DATE=$(fn_get_date_from_dirpath "${RES}")
    DATE_DIFF="$(fn_date_diff "$(date +%s)" "$(date -d "${DATE}" +%s)") ago"

    NEW_RES+="${DATE_DIFF}"$'\n'
    NEW_RES+="${RES}"$'\n'
  done
  if [ -n "${NEW_RES}" ]; then
    NEW_RES="${NEW_RES::-1}"
  fi
  echo -n "${NEW_RES}"
}
export -f fn_get_timeshift_columns

################################################################################

# GUI functions

export MENU_KEY=100
export CREATE_BAKUP_KEY=200

fn_draw_menu_window() {
  ipcrm -M ${MENU_KEY} 2> /dev/null # fixing `yad: cannot create shared memory for key 100: File exists`

  local TXT="$1"
  local HOME_NUM="$2"
  local TIMESHIFT_NUM="$3"
  local INCOMPLETE_NUM="$4"
  local CANCEL_BUTTON_NAME="$5"
  local KEY_WORD="$6"

  TAB_ARR["$2"]="Home"
  TAB_ARR["$3"]="TimeShift"
  TAB_ARR["$4"]="Incomplete"

  # Main dialog
  TXT+="\\n\\n"
  TXT+="<b>Hardware system information</b>\\n"
  TXT+="\\tOS: $(lsb_release -ds)\\n"
  #TXT+="\\tUser: ${USER}\\n"
  TXT+="\\tHostname: $(hostname)\\n"
  TXT+="\\tKernel: $(uname -sr)\\n"

  # Home tab
  DEST_DIRS=$(fn_get_dir_columns fn_get_date_from_dirpath "????-??-??_??-??-??")
  echo "${DEST_DIRS}" | \
    yad --plug=${MENU_KEY} --tabnum="${HOME_NUM}" --image="administration" --text="Home backups" \
      --list \
      --no-selection \
      --column="Modified" --column="Dir" --column="Path" &

  # TimeShift tab
  BACKUP_DIRS=$(fn_get_timeshift_columns)
  echo "${BACKUP_DIRS}" | \
    yad --plug=${MENU_KEY} --tabnum="${TIMESHIFT_NUM}" --image="administration" --text="TimeShift backups" \
      --list --no-selection --column="Modified" --column="Path" &

  # Incomplete tab
  DEST_DIRS=$(fn_get_dir_columns fn_get_date_from_incomplete_path "????-??-??_??-??-??_INCOMPLETE")
  echo "${DEST_DIRS}" | \
    yad --plug=${MENU_KEY} --tabnum="${INCOMPLETE_NUM}" --image="administration" --text="Incomplete backups" \
      --list --no-selection \
      --column="Modified" --column="Dir" --column="Path" &

  # Buttons handling
  if [ "${KEY_WORD}" = "Menu" ]; then
    # add '--on-top --fixed' options
    yad --notebook \
        --no-escape \
        --skip-taskbar \
        --window-icon="important" \
        --width=800 --height=550 --center \
        --buttons-layout=center \
        --title="${ENV_APP_TITLE} (Menu)" \
        --text="Something" \
        --text="${TXT}" \
        --button="Create <b>full</b> backup now"!clock:2 \
        --button="Remove <b>incomplete</b> backups"!clock:0 \
        --button="${CANCEL_BUTTON_NAME}"!gtk-cancel:1 \
        --key=${MENU_KEY} \
        --tab="${TAB_ARR[1]}" --tab="${TAB_ARR[2]}" --tab="${TAB_ARR[3]}"
  else
#    --button="Create <b>full</b> backup now"!clock:2 \
#    --button="Create ${KEY_WORD} backup <b>now</b>"!dialog-ok:0 \
#    --button="${CANCEL_BUTTON_NAME}"!gtk-cancel:1 \
    yad --notebook \
        --no-escape \
        --skip-taskbar \
        --window-icon="important" \
        --width=800 --height=550 --center \
        --buttons-layout=end \
        --title="${ENV_APP_TITLE} (Menu)" \
        --text="Something" \
        --text="${TXT}" \
        --button="OK"!dialog-ok:0 \
        --key=${MENU_KEY} \
        --tab="${TAB_ARR[1]}" --tab="${TAB_ARR[2]}" --tab="${TAB_ARR[3]}"
  fi

  YAD_EXIT_STATUS=$?
  echo -n "${YAD_EXIT_STATUS}"
}
export -f fn_draw_menu_window

################################################################################

fn_draw_create_backup_window() {
  ipcrm -M ${CREATE_BAKUP_KEY} 2> /dev/null # fixing `yad: cannot create shared memory for key 100: File exists`

  # --image=gnome-shutdown
  # "No backup" "fn_power_off" \
  yad --plug=${CREATE_BAKUP_KEY} --tabnum=1 \
    --list --no-headers \
    --image=backups-app \
    --borders=10 \
    --text="<b>Choose action</b>" --text-align=center \
    --column=Name --column=Operation --hide-column=2 \
    "Backup \"/home\"" "fn_backup_home" \
    "Backup System" "fn_backup_system" \
    "Full Backup" "fn_full_backup" &

  yad --plug=${CREATE_BAKUP_KEY} --tabnum=2 --form \
      --field=$"Power Off after action:chk" 'TRUE' &
  # add '--on-top --fixed' options
  YAD_RES=$(
    yad --paned --key=${CREATE_BAKUP_KEY} \
        --no-escape \
        --skip-taskbar \
        --window-icon=boot \
        --title="${ENV_APP_TITLE} (Create Backup)" \
        --width=370 --height=230 --center --splitter=145 \
        --buttons-layout=spread \
        --button="OK"!dialog-ok:0 \
        --button="gtk-cancel":1
  )
  YAD_EXIT_STATUS=$?
  echo -n "${YAD_EXIT_STATUS}"
}
export -f fn_draw_create_backup_window

################################################################################
