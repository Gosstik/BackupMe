# Remove incomplete backups

# TODO: create countdown

INCOMPLETE_DIRS=$(find "${BACKUP_DIR}/" -maxdepth 1 -type d -name "????-??-??_??-??-??_INCOMPLETE")
if [ -n "${INCOMPLETE_DIRS}" ]; then
  echo -e "Incomplete dirs are found, will be removed in"
  for i in {5..1};do echo -n " $i" && sleep 1; done

  echo "${INCOMPLETE_DIRS}" |
  while read -r DIR_TO_REMOVE; do
    fn_remove_log_and_backup_dir "${DIR_TO_REMOVE}"
  done
fi

################################################################################

# Prefer use fn_file_mutex

#Usage: fn_create_lock_file "backup_creator-${SRC_SLASHED_NAME}"
fn_create_lock_file() {
  # $1 must be name of lock file
  local SCRIPT_DIR LOCK_DIR PID_FILE RUNNING_PID

  SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
  LOCK_DIR="${SCRIPT_DIR}/$1.lock"
  PID_FILE="${LOCK_DIR}/PID"
  echo "creating lock... ${LOCK_DIR}"
  if mkdir "${LOCK_DIR}" 2>/dev/null; then
    echo "lock for $$ acquired"
    echo "$$" > "${PID_FILE}"

    # Remove LOCK_DIR when the script finishes, or when it receives a signal
    # (except kill -9 --- SIGKILL and SIGSTOP)
    trap 'rm -rf "$LOCK_DIR"' INT QUIT TERM EXIT USR1
  else
    RUNNING_PID=$(cat ${PID_FILE} 2>/dev/null)
    echo "script is already running, PID: ${RUNNING_PID:-already expired}"
    exit 0
  fi
}

fn_remove_lock_file() {
  kill -SIGUSR1 $$
}

################################################################################

fn_create_latest_link() {
  DEST_DIRS=$(find "${BACKUPS_STORAGE_DIR}/" -maxdepth 1 -type d -name "????-??-??_??-??-??" | sort -r)
  LATEST_LINK=$(echo "${DEST_DIRS}" | sed -n "1p")
}

################################################################################
