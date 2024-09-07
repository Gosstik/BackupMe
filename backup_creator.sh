#!/bin/bash

# A script to perform incremental backups using rsync

### Args:
# $1 --- SRC_DIR (example: /home/gostik)

################################################################################

echo "backup_creator.sh was called with \$1='$1'"

################################################################################

# Get SRC_DIR for lock file

#SRC_DIR="/home/gostik"
SRC_DIR=$(fn_get_src_dir_with_checks "$1")
SRC_SLASHED_NAME="${SRC_DIR//\//_}"

################################################################################

# Sourcing utils

BASH_SOURCE_ABS=$(realpath "${BASH_SOURCE[0]}")
BASH_SOURCE_NAME=$(basename "${BASH_SOURCE_ABS}")
BASH_SOURCE_DIR=$(dirname "${BASH_SOURCE_ABS}")
PROJECT_DIR="${BASH_SOURCE_DIR}"
source "${PROJECT_DIR}/util.sh"

fn_request_sudo
fn_acquire_file_mutex "backup_creator-${SRC_SLASHED_NAME}.lock"
fn_import_env_variables

################################################################################

# Check .env and passed variables

# ENV_MAX_DEST_DIRS_COUNT is defined in .env
MIN_DEST_DIRS_COUNT=1
if [ ${ENV_MAX_DEST_DIRS_COUNT} -lt ${MIN_DEST_DIRS_COUNT} ]; then
  echo "invalid MAX_DEST_DIRS_COUNT: '${ENV_MAX_DEST_DIRS_COUNT}', required at least ${MIN_DEST_DIRS_COUNT}"
  ENV_MAX_DEST_DIRS_COUNT=MIN_DEST_DIRS_COUNT
fi

################################################################################

# Setting variables

BACKUP_DIR="${ENV_BACKUPS_STORAGE_DIR}/${SRC_SLASHED_NAME}"
mkdir -p "${BACKUP_DIR}"
LATEST_LINK="${BACKUP_DIR}/latest"

# DEST_DIR
CURRENT_TIME=$(date +"%Y-%m-%d_%H-%M-%S") # current time
DEST_DIR="${BACKUP_DIR}/${CURRENT_TIME}"
DEST_DIR_LOG_COMMAND="${BACKUP_DIR}/${CURRENT_TIME}_rsync_cmd.log"
TMP_DEST_DIR="${DEST_DIR}_INCOMPLETE"

################################################################################

# RSYNC_FLAGS and RECOVERY_FLAG

RSYNC_FLAGS=""
#RSYNC_FLAGS+="-n " # dry run
#RSYNC_FLAGS+="-v " # print all files
RSYNC_FLAGS+="-c " # compare file content instead of size or modification time
RSYNC_FLAGS+="--archive "
RSYNC_FLAGS+="--one-file-system " # don't cross filesystem boundaries
RSYNC_FLAGS+="--links " # When symlinks are encountered, recreate the symlink on the destination.
RSYNC_FLAGS+="--hard-links " # This tells rsync to look for hard-linked files in the transfer and link together the corresponding files on the receiving side.
RSYNC_FLAGS+="--numeric-ids "
RSYNC_FLAGS+="--delete "
RSYNC_FLAGS+="--delete-excluded "
RSYNC_FLAGS+="--stats " # print a verbose set of statistics
RSYNC_FLAGS+="--delete-excluded "
RSYNC_FLAGS+="--human-readable "
RSYNC_FLAGS+="--itemize-changes "
#RSYNC_FLAGS+="--progress "
#RSYNC_FLAGS+="--info=progress2 "
#RSYNC_FLAGS+="--no-inc-recursive "

RECOVERY_FLAGS="${RSYNC_FLAGS}";

# --link-dest

if [ -L "${LATEST_LINK}" ]; then
  LATEST_BACKUP_DIR=$(readlink -n "${LATEST_LINK}")
  if [ -d "${LATEST_BACKUP_DIR}" ]; then
    RSYNC_FLAGS+="--link-dest ${LATEST_BACKUP_DIR} "
  fi
fi

# rsync logs and excludes

mkdir -p "${BACKUP_DIR}/logs"
RSYNC_FLAGS+="--log-file=${BACKUP_DIR}/logs/${CURRENT_TIME}.log "
RSYNC_FLAGS+="--exclude-from=${PROJECT_DIR}/data/home-excludes.txt"

################################################################################

# Create backup

mkdir -p "${TMP_DEST_DIR}"
RSYNC_CMD="rsync ${RSYNC_FLAGS} ${SRC_DIR} ${TMP_DEST_DIR}"
SRC_DIR_NAME=$(basename "${SRC_DIR}")
RECOVERY_CMD="sudo rsync ${RECOVERY_FLAGS} ${DEST_DIR}/${SRC_DIR_NAME} /mnt/System${SRC_DIR}"
echo -e "Initial CMD:\n${RSYNC_CMD}\n\nRecovery CMD:\n${RECOVERY_CMD}" > "${DEST_DIR_LOG_COMMAND}"
#set +o errexit # if there are troubles with file permissions
${RSYNC_CMD}
#set -o errexit
mv "${TMP_DEST_DIR}" "${DEST_DIR}"

rm -rf "${LATEST_LINK}"
ln -s "${DEST_DIR}" "${LATEST_LINK}"
