# BackupMe

Backup utility for Ubuntu distributions. Backups system with `TimeShift` and `Home` directories with `rsync`. Old backups are deleted only when a new one is created. There is an option `ENV_DELETE_OLDEST_BACKUP` in order to ensure that you have at least one working backup.

## Dependencies

They are installed automatically with `install.sh`.
```bash
# System backup
sudo apt-get install timeshift

# yad GUI
sudo apt-get install yad

# Make apps from scripts and choose icons with 'Icon Browser'
sudo apt-get install alacarte

# Cron
sudo apt-get install cron
```

## Installation

After cloning repo, you have to (order is extremely important):
1) Change `.env` file as you wish.
2) Run `sudo ./install.sh`. There will be interactive part --- always choose `yes`, `ok` or press `enter`.

**NOTE**: There must be **no spaces** in path to directories for backup and that storing backups.


## Recovery

### From Live CD/USB
- System: mount partition with `timeshift` backups and run:
```bash
sudo apt-get install timeshift
# For further actions it is better to use GUI.
# Ic case GUI is is unavailable, do the following:
sudo timeshift --restore
timeshift # for help
sudo timeshift --list --snapshot-device /dev/nvme0n1p<backup_num> # list accessible backups
sudo timeshift --restore \
  --snapshot-device /dev/nvme0n1p<backup_num> --snapshot '2014-10-12_16-29-08' \
  --target /dev/nvme0n1p<system_num>
```

- Home.
```bash
# Find partitions with backup (<BACKUP_DEV>) and target system (<SYSTEM_DEV>)
sudo -s
lsblk

# Mounting them to the following directories
mkdir -p /mnt/OSbackups
mount <BACKUP_DEV> /mnt/OSbackups
mkdir -p /mnt/target_sys
mount <SYSTEM_DEV> /mnt/System

# Find command for the latest backup of <USER_DIR> (both yours and root)
LATEST=readlink /mnt/OSbackups/rsync/<USER_DIR>/latest
cat "${LATEST}_rsync_cmd.log" # output recovery CMD
#rm -rf <USER_DIR>/* # in case recovery does not help
<RECOVERY_CMD>
```

**NOTE:** New files, that have appeared in `$USER` directory are not deleted during recovery. You may have to delete them manually in case they are not compatible with backup content.

# Debug

To see error before terminal is closed, uncomment `fn_exit_on_enter` in files in `cron` and `gui_apps` dirs.

## Cron

**NOTE:** `crontab -u root -l` does not list jobs inside `/etc/cron.d`. For that purpose it is comfortable to use `cronitor list`:
```bash
# Installation
wget https://cronitor.io/dl/linux_amd64.tar.gz
sudo tar xvf linux_amd64.tar.gz -C /usr/local/bin/
rm -rf linux_amd64.tar.gz

# Usage
cronitor list
```

Crontab logs and active jobs:
```bash
# List cron jobs. Jobs inside /etc/cron.d are not displayed!!!
crontab -u root -l

# Logs
cat /var/log/cron # may not work
cat /var/log/syslog

# More convenient way
grep -i cron /var/log/syslog # check for syntax errors on cron file
grep backup_me /var/log/syslog # check for script execution

# Reload cron (in fact, it must reload by itself)
service cron reload # Option 1
/etc/init.d/cron reload # Option 2
```

Location of cron files you can see in `install.sh`.

### Cron errors

- from `/var/log/syslog`: [No MTA installed, discarding output](https://cronitor.io/guides/no-mta-installed-discarding-output). It means that `cron` is unable to send output from your script by email.
- In newest systems it is forbidden to run GUI applications as a root. Therefore, in cron job we must explicitly enable it and disable with the help of that commands:
```bash
su -c 'xhost +si:localuser:root' gostik # enable run GUI as root
su -c 'xhost -si:localuser:root' gostik # disable run GUI as root
```
- `find: ‘/home/gostik/.gvfs’: Permission denied`: [askubuntu.com](https://askubuntu.com/questions/524667/ls-cannot-access-gvfs-permission-denied)
- `xhost:  unable to open display ":1"`. It is occurred when system is loaded, but user has not yet entered his password. Cron job waits for 5 minutes and then fails.

# TODO

- install on VM
- test recover on `gostik` dir
- Progress of `rsync` with `yad`: https://serverfault.com/questions/219013/showing-total-progress-in-rsync-is-it-possible

# Handy

- backup-before-shutdown idea: [askubuntu.com](https://askubuntu.com/questions/1323632/backup-before-shutdown)
- GUI alternatives on [stackoverflow](https://stackoverflow.com/questions/7035/how-to-show-a-gui-message-box-from-a-bash-script-in-linux)
- Choose icons with `Icon Browser` [install alacarte app: Main Menu](https://superuser.com/questions/1282203/how-do-i-add-a-shortcut-to-the-show-applications-menu-in-ubuntu-17)
- `.desktop` specs keys: [specifications.freedesktop.org](https://specifications.freedesktop.org/desktop-entry-spec/latest/recognized-keys.html)
- `.desktop` setup: [dev.to](https://dev.to/ha7shu/how-to-create-a-desktop-entry-in-linux-23p9)
- In short about `cron`: [opensource.com](https://opensource.com/article/17/11/how-use-cron-linux)
- Enable Hibernate on Ubuntu: [askubuntu.com](https://askubuntu.com/a/385316)
- It is extremely poor to run GUI applications with `sudo`.
```bash
# Nautilus for sudo usage
sudo apt install nautilus-admin

# Show which dirs/files in home $USER directory belongs to `root`  
find ~ -user root

# Change owner for all home files
sudo chown -R gostik /home/gostik
```

# Bugs

- If there are troubles with file permissions, try to add that file to `{PROJECT_DIR}/data/home-excludes.txt`. If it does not resolve a problem, uncomment `set +o errexit` in `backup_creator.sh`.
- `Authorization required, but no authorization protocol specified` --- try to manually run `${PROJECT_DIR}/cron/pc_startup.sh`
