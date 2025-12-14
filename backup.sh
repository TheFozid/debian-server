#!/bin/bash

# Config
LOGFILE="/home/trycoo/logs/backup.log"
EMAIL="my@email.com"


# Pre-backup: Run root-backup.sh if mountpoint is available
PRE_MOUNT="/home/cloud/cloud"
ROOT_BACKUP_SCRIPT="/home/trycoo/scripts/root-backup.sh"

if mountpoint -q "$PRE_MOUNT"; then
    if bash "$ROOT_BACKUP_SCRIPT"; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') SUCCESS [Pre-sync] root-backup.sh executed successfully" >> "$LOGFILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') FAIL [Pre-sync] root-backup.sh failed" >> "$LOGFILE"
        echo -e "Root backup script failed on $(hostname) at $(date)" | mail -s "Root Backup Failed" "$EMAIL"
    fi
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') WARN [Pre-sync] $PRE_MOUNT is not mounted, skipping pre-backup root sync" >> "$LOGFILE"
fi


# Utility Functions

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOGFILE"
}

send_failure_email() {
    local subject="$1"
    local body="$2"
    echo -e "$body" | mail -s "$subject" "$EMAIL"
}

run_backup() {
    local src="$1"
    local dest="$2"
    local mountpoint="$3"
    local job_desc="$src -> $dest (mount: $mountpoint)"

    # Mount the filesystem
    if ! mountpoint -q "$mountpoint"; then
        if ! mount "$mountpoint"; then
            log "FAIL [$job_desc] Could not mount $mountpoint"
            send_failure_email "Backup Failed: $job_desc" "Failed to mount $mountpoint"
            return 1
        fi
    fi

    # Double check mount
    if ! mountpoint -q "$mountpoint"; then
        log "FAIL [$job_desc] Not mounted after attempt"
        send_failure_email "Backup Failed: $job_desc" "Mountpoint $mountpoint not available."
        return 1
    fi

    # Run rsync
    if rsync -a --delete "$src/" "$dest/"; then
        log "SUCCESS [$job_desc]"
    else
        log "FAIL [$job_desc] rsync failure"
        send_failure_email "Backup Failed: $job_desc" "rsync failed for $src to $dest"
        return 1
    fi

    # Unmount after backup
    if ! umount "$mountpoint"; then
        log "WARN [$job_desc] Could not unmount $mountpoint"
    fi
}

DAY=$(date +%d)
DAY_NUM=$(echo $DAY | sed 's/^0*//') # Remove leading zero
EVEN_ODD=$(( DAY_NUM % 2 ))

# Even or Odd Short backup jobs
if [ $EVEN_ODD -eq 0 ]; then
    # Even days
    run_backup "/home/cloud/cloud" "/home/trycoo/backups/short/even/cloud" "/home/trycoo/backups/short"
    run_backup "/home/cloud/abe"   "/home/trycoo/backups/short/even/abe"   "/home/trycoo/backups/short"
else
    # Odd days
    run_backup "/home/cloud/cloud" "/home/trycoo/backups/short/odd/cloud" "/home/trycoo/backups/short"
    run_backup "/home/cloud/abe"   "/home/trycoo/backups/short/odd/abe"   "/home/trycoo/backups/short"
fi

# Long backup jobs on 1st and 15th
if [ "$DAY_NUM" -eq 1 ] || [ "$DAY_NUM" -eq 15 ]; then
    run_backup "/home/cloud/cloud" "/home/trycoo/backups/long/1-15/cloud" "/home/trycoo/backups/long"
    run_backup "/home/cloud/abe"   "/home/trycoo/backups/long/1-15/abe"   "/home/trycoo/backups/long"
fi

# Long backup jobs on 8th and 22nd
if [ "$DAY_NUM" -eq 8 ] || [ "$DAY_NUM" -eq 22 ]; then
    run_backup "/home/cloud/cloud" "/home/trycoo/backups/long/8-22/cloud" "/home/trycoo/backups/long"
    run_backup "/home/cloud/abe"   "/home/trycoo/backups/long/8-22/abe"   "/home/trycoo/backups/long"
fi

exit 0
