#!/bin/bash

# Install BackupMe on PC

################################################################################

# Sourcing utils

BASH_SOURCE_ABS=$(realpath "${BASH_SOURCE[0]}")
BASH_SOURCE_NAME=$(basename "${BASH_SOURCE_ABS}")
BASH_SOURCE_DIR=$(dirname "${BASH_SOURCE_ABS}")
PROJECT_DIR="${BASH_SOURCE_DIR}"
source "${PROJECT_DIR}/util.sh"

fn_request_sudo
fn_import_env_variables

mkdir -p "${ENV_BACKUPS_STORAGE_DIR}"
mkdir -p "${ENV_TIMESHIFT_BACKUP_DIR}"

################################################################################

# Install dependencies

echo "Installing dependencies..."

apt-get update
apt-get install -y timeshift \
                   yad \
                   alacarte \
                   cron \
                   pv

echo "Dependencies installed!"

#systemctl status cron.service > /dev/null # check Cron is installed

################################################################################

# Create desktop icons

echo "Creating desktop icons..."

# menu.sh
MENU_TEXT=$(cat "${PROJECT_DIR}/desktop/backup-me-menu.desktop")
MENU_TEXT="${MENU_TEXT%$'\n'*}" # removing default Exec
MENU_TEXT+=$'\n'"Exec=${PROJECT_DIR}/gui_apps/menu.sh"
MENU_DESKTOP="/usr/share/applications/backup-me-menu.desktop"
echo "${MENU_TEXT}" > "${MENU_DESKTOP}"
chmod u+x "${MENU_DESKTOP}"

# create_backup.sh
CREATE_BACKUP_TEXT=$(cat "${PROJECT_DIR}/desktop/backup-me-create-backup.desktop")
CREATE_BACKUP_TEXT="${CREATE_BACKUP_TEXT%$'\n'*}" # removing default Exec
CREATE_BACKUP_TEXT+=$'\n'"Exec=${PROJECT_DIR}/gui_apps/create_backup.sh"
CREATE_BACKUP_DESKTOP="/usr/share/applications/backup-me-create-backup.desktop"
echo "${CREATE_BACKUP_TEXT}" > "${CREATE_BACKUP_DESKTOP}"
chmod u+x "${CREATE_BACKUP_DESKTOP}"

update-desktop-database

echo "Desktop icons created!"

################################################################################

# Setup cron jobs

# Creating directories and sym-link to cron-script
echo "Creating directories and sym-link to cron-script"
mkdir -p "${ENV_CRON_LOGS_DIR}"
mkdir -p "/etc/cron.reboot" # for crontab file
ln -fs "${PROJECT_DIR}/cron/pc_startup.sh" "/etc/cron.reboot/backup_me-pc_startup"

# Make crontab file
echo "Make crontab file"
CRONTAB_FILE="/etc/cron.d/backup-me"
CRONTAB_FILE_CONTENT=$(cat "${PROJECT_DIR}/cron/backup-me.cron")
CRONTAB_FILE_CONTENT="${CRONTAB_FILE_CONTENT//"<ENV_CRON_LOGS_DIR>"/"${ENV_CRON_LOGS_DIR}"}"
CRONTAB_FILE_CONTENT="${CRONTAB_FILE_CONTENT//"<ENV_DISPLAY>"/${DISPLAY}}"
echo "${CRONTAB_FILE_CONTENT}" > "${CRONTAB_FILE}"

echo "Cron job created. Remove '${CRONTAB_FILE}' to stop it."

################################################################################

# Not used yet
echo "ENV_DISPLAY=${DISPLAY}" > ".local.env"

################################################################################

# Reinstalling gnome-terminal and locales (REQUIRES REBOOT!!!)

echo "!!!!!!!! Reinstalling gnome-terminal and locales !!!!!!!!"

sudo apt-get install -y dconf-cli

# Reinstalling terminal
dconf reset -f /org/gnome/terminal
sudo apt-get remove -y gnome-terminal
sudo apt-get install -y gnome-terminal

# Reconfiguring locale
sudo locale-gen --purge
sudo dpkg-reconfigure locales

################################################################################

sudo apt-get autoremove -y

read -r -n 1 -p "To finish installation, reboot is required. Reboot now? (print 'y' to accept): "
if [ -n "${REPLY}" ] && [ "${REPLY}" = "y" ]; then
  reboot
else
  echo -e "\nReject rebooting"
fi
