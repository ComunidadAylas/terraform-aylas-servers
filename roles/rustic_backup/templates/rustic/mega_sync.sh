#!/bin/sh -eu

readonly BACKUP_DIR='/backups/{{ item.identifier }}'
readonly MEGA_FOLDER='{{ item.mega_folder }}'

echo "$(date) Setting up synchronization of repository at $BACKUP_DIR to MEGA folder $MEGA_FOLDER"

mega-login '{{ item.mega_user }}' '{{ item.mega_password }}' || true
mega-sync --remove "$BACKUP_DIR" || true
mega-sync "$BACKUP_DIR" "$MEGA_FOLDER" || true

echo "$(date) Waiting for repository to be synchronized..."

while
  sleep 1
  sync_status=$(mega-sync --enable --output-cols='STATUS' "$BACKUP_DIR")
  [ "$(echo "$sync_status" | tail -1)" != 'Synced' ]
do
  sleep 1
done
mega-sync --remove "$BACKUP_DIR"
mega-quit || true

echo "$(date) Synchronization complete"
