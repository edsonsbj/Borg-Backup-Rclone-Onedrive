#!/bin/bash

CONFIG="$(dirname "${BASH_SOURCE[0]}")/BackupRestore.conf"
. $CONFIG

# Create a log file to record command outputs
touch "$LogFile"
exec > >(tee -a "$LogFile")
exec 2>&1

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

## ---------------------------------- TESTS ------------------------------ #
# Check if the script is being executed by root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo "========== This script needs to be executed as root or with sudo. ==========" 
   exit 1
fi

# -------------------------------FUNCTIONS----------------------------------------- #
BORG_OPTS="--verbose --filter AME --list --progress --stats --show-rc --compression lz4 --exclude-caches"

# Start Rclone Mount    
systemctl start borgbackup.service

#
 Function to Nextcloud Maintenance Mode
nextcloud_enable() {
    # Enabling Maintenance Mode
	sudo -u www-data php $NextcloudConfig/occ maintenance:mode --on
}

nextcloud_disable() {
    # Disabling Nextcloud Maintenance Mode
	sudo -u www-data php $NextcloudConfig/occ maintenance:mode --off
}

# Function to WebServer Stop Start
stop_webserver() {
    # Stop Web Server
	systemctl stop $webserverServiceName
}

start_webserver() {
    # Stop Media Server
    systemctl stop "$MediaserverService"
}

# Function to WebServer Stop Start
stop_mediaserver() {
    # Stop Media Server
    systemctl stop "$MediaserverService"
}

start_mediaserver() {
    # Start Media Server
	systemctl start $webserverServiceName
}

# Function to backup Nextcloud settings
nextcloud_settings() {
    echo "========== Backing up Nextcloud settings $( date )... =========="
    echo ""

    nextcloud_enable

    stop_webserver

   	# Export the database.
	mysqldump --quick -n --host=localhost $NextcloudDatabase --user=$DBUser --password=$DBPassword > "$NextcloudConfig/nextclouddb.sql"

    # Backup
    borg create $BORG_OPTS ::'NextcloudConfigs-{now:%Y%m%d-%H%M}' $NextcloudConfig --exclude $NextcloudDataDir

    backup_exit=$?

    # Remove the database
    rm "$NextcloudConfig/nextclouddb.sql"

    start_webserver
    
    nextcloud_disable
}

# Function to backup Nextcloud DATA folder
nextcloud_data() {
    echo "========== Backing up Nextcloud DATA folder $( date )...=========="
    echo ""

    nextcloud_enable

    borg create $BORG_OPTS ::'NextcloudData-{now:%Y%m%d-%H%M}' $NextcloudDataDir --exclude "$NextcloudDataDir/*/files_trashbin"

    backup_exit=$?

    nextcloud_disable
}

# Function to perform a complete Nextcloud backup
nextcloud_complete() {
    echo "========== Backing up Nextcloud $( date )... =========="
    echo ""
    
    nextcloud_enable

    stop_webserver

   	# Export the database.
	mysqldump --quick -n --host=localhost $NextcloudDatabase --user=$DBUser --password=$DBPassword > "$NextcloudConfig/nextclouddb.sql"

    # Backup
    borg create $BORG_OPTS ::'NextcloudFull-{now:%Y%m%d-%H%M}' $NextcloudConfig $NextcloudDataDir --exclude "$NextcloudDataDir/*/files_trashbin"

    backup_exit=$?

    # Remove the database
    rm "$NextcloudConfig/nextclouddb.sql"

    start_webserver

    nextcloud_disable
}

# Function to backup Nextcloud and Media Server settings
nextcloud_mediaserver_settings() {
    # Filters for Inclusion Exclusion Borg
    BorgFilters="./patterns.lst"

    # Create a file with the delete standards Borg Inclusion
    tee -a "$BorgFilters" <<EOF
P sh
R /

# DO NOT LOOK IN THESE FOLDERS
! proc

# DIRECTORIES TO BE EXCLUDED FROM BACKUP  

# Media Server
- $MediaserverConf/Cache
- $MediaserverConf/cache
- $MediaserverConf/Crash Reports
- $MediaserverConf/Diagnostics
- $MediaserverConf/Logs
- $MediaserverConf/logs
- $MediaserverConf/transcoding-temp

# NEXTCLOUD
- $NextcloudDataDir

# DIRECTORIES FOR BACKUP 

# Media Server Include
+ $MediaserverConf/

# NEXTCLOUD - SETTINGS
+ $NextcloudConfig/

# DO NOT INCLUDE ANY MORE FILES
- **
EOF

    echo "========== Backing up Nextcloud and Media Server settings $( date )... =========="
    echo ""

    nextcloud_enable

    stop_webserver

    stop_mediaserver

   	# Export the database.
	mysqldump --quick -n --host=localhost $NextcloudDatabase --user=$DBUser --password=$DBPassword > "$NextcloudConfig/nextclouddb.sql"

    # Backup
    borg create $BORG_OPTS --patterns-from "$BorgFilters" ::'SettingsServer-{now:%Y%m%d-%H%M}'

    backup_exit=$?

    # Remove unnecessary files
    rm "$NextcloudConfig/nextclouddb.sql"
    rm "$BorgFilters"

    nextcloud_disable

    start_webserver

    start_mediaserver
}

# Function to backup Nextcloud and Media Server settings
nextcloud_mediaserver_complete() {
    # Filters for Inclusion Exclusion Borg
    BorgFilters="./patterns.lst"

    # Create a file with the delete standards Borg Inclusion
    tee -a "$BorgFilters" <<EOF
P sh
R /

# DO NOT LOOK IN THESE FOLDERS
! proc

# DIRECTORIES TO BE EXCLUDED FROM BACKUP  

# Media Server
- $MediaserverConf/Cache
- $MediaserverConf/cache
- $MediaserverConf/Crash Reports
- $MediaserverConf/Diagnostics
- $MediaserverConf/Logs
- $MediaserverConf/logs
- $MediaserverConf/transcoding-temp

# NEXTCLOUD
- $NextcloudDataDir/*/files_trashbin

# DIRECTORIES FOR BACKUP 

# Media Server Include
+ $MediaserverConf/

# NEXTCLOUD - SETTINGS
+ $NextcloudConfig/
+ $NextcloudDataDir/

# DO NOT INCLUDE ANY MORE FILES
- **
EOF

    echo "========== Backing up Nextcloud and Media Server settings $( date )... =========="
    echo ""

    nextcloud_enable

    stop_webserver

    stop_mediaserver

   	# Export the database.
	mysqldump --quick -n --host=localhost $NextcloudDatabase --user=$DBUser --password=$DBPassword > "$NextcloudConfig/nextclouddb.sql"

    # Backup
    borg create $BORG_OPTS --patterns-from "$BorgFilters" ::'SettingsServer-{now:%Y%m%d-%H%M}'

    backup_exit=$?

    # Remove unnecessary files
    rm "$NextcloudConfig/nextclouddb.sql"
    rm "$BorgFilters"

    nextcloud_disable

    start_webserver

    start_mediaserver
}

# Check if an option was passed as an argument
if [[ ! -z $1 ]]; then
    # Execute the corresponding Backup option
    case $1 in
        1)
            nextcloud_settings
            ;;
        2)
            nextcloud_data
            ;;
        3)
            nextcloud_complete
            ;;
        4)
            nextcloud_mediaserver_settings
            ;;
        5)
            nextcloud_mediaserver_complete
            ;;               
        *)
            echo "Invalid option!"
            ;;
    esac
else
    # Display the menu to choose the Backup option
    echo "Choose a Backup option:"
    echo "1. Backup Nextcloud configurations and database."
    echo "2. Backup only the Nextcloud data folder. Useful if the folder is stored elsewhere."
    echo "3. Backup Nextcloud configurations, database, and data folder."
    echo "4. Backup Nextcloud and Media Server Settings."
    echo "5. Backup Nextcloud settings, database and data folder, as well as Media Server settings."
    echo "6. To go out."

    # Read the option entered by the user
    read option

    # Execute the corresponding Backup option
    case $option in
        1)
            nextcloud_settings
            ;;
        2)
            nextcloud_data
            ;;
        3)
            nextcloud_complete
            ;;
        4)
            nextcloud_mediaserver_settings
            ;;
        5)
            nextcloud_mediaserver_complete
            ;;             
        6)
            echo "Leaving the script."
            exit 0
            ;;            
        *)
            echo "Invalid option!"
            ;;
    esac
fi

    info "Pruning repository"

    # Use the subcoming `prune` to keep 7 days, 4 per week and 6 per month
    # files of this machine.The prefix '{hostname}-' is very important for
    # limits PLA's operation to files in this machine and does not apply to
    # Files of other machines too:

    borg prune --list --progress --show-rc --keep-daily 7 --keep-weekly 4 --keep-monthly 6

    prune_exit=$? 

    # Sleep for 3 hours before unmounting the drive
    sleep 10800

    # Stop Rclone Mount    
    systemctl stop borgbackup.service


# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup, Prune finished successfully" 2>&1 | tee -a
elif [ ${global_exit} -eq 1 ]; then
    info "Backup, Prune finished with warnings" 2>&1 | tee -a
else
    info "Backup, Prune finished with errors" 2>&1 | tee -a
fi