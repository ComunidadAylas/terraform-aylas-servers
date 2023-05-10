#!/bin/sh -e

# Manages the lifecycle of a Purpur Minecraft server, doing update and backup
# tasks before running a server, and offering the user to restore backups or
# restart a server when it stops. It also ensures that the server can be managed
# by other processes via the tools offered by the rcon package.
#
# Other processes can control the server by sending POSIX signals to this process:
# - SIGPWR: if the server is running, it signals that the server should be
#   automatically restarted the next time it stops.
# - SIGUSR1: signals that the server should back up its data before starting
#   for the next time. Backup logs are stored at BACKUP_LOG_FILE_PATH (see below).
# - SIGUSR2: signals that the server should update the Purpur launcher before
#   starting for the next time.
#
# Before starting, this controller writes its PID at PID_FILE_PATH (see
# server_ipc_vars).
#
# If the server is stopped and has been run at least once, STOPPED_FLAG_FILE is
# guaranteed to exist.
#
# The server can be gracefully stopped by running "rconclt server stop".
#
# Requires curl and, if Discord notifications are used, jq.

# shellcheck source=server_ipc_vars
. ~/.local/bin/server_ipc_vars

# ---

readonly DATA_FOLDER="${XDG_DATA_HOME:-$HOME/.local/share}/server_controller"
mkdir -p "$DATA_FOLDER"

# ---

readonly LAST_MC_VERSION_FILE="$DATA_FOLDER/last_mc_version"
readonly TEMPORARY_FILE_SUFFIX=.controller.tmp

readonly BACKUP_LOG_FILE_PATH="$DATA_FOLDER/backup_log"

# ---

readonly STATE_FILES_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"/purpur-mc-server
mkdir -p "$STATE_FILES_DIR"

readonly BACKUP_AT_NEXT_START_FLAG_FILE="$STATE_FILES_DIR/backup"
readonly UPDATE_AT_NEXT_START_FLAG_FILE="$STATE_FILES_DIR/update"

# ---

atomic_rename_successor_file() {
  # The syncfs() call is needed to avoid moving a corrupt new file
  # in some cases. Related read: https://lwn.net/Articles/789600/
  sync -f "$1$TEMPORARY_FILE_SUFFIX"
  mv -f "$1$TEMPORARY_FILE_SUFFIX" "$1"
}

# shellcheck disable=SC1054,SC1083
{% if discord_notifications.webhook_url is defined %}
send_notification() {
  payload=$(jq -nc \
    --arg title "$1" \
    --arg description "$2" \
    --arg color "$3" \
    '{
      content: "",
      embeds: [
        {
          title: $title,
          description: $description,
          color: ($color | tonumber),
          footer: {
            text: "🔔 Automated Minecraft server controller notification"
          }
        }
      ]
    }') && \
  curl \
    --header 'Content-Type: application/json' \
    -d "$payload" \
    '{{ discord_notifications.webhook_url }}' >/dev/null 2>&1 || true
}
# shellcheck disable=SC1009,1083
{% else %}
send_notification() { :; }
# shellcheck disable=SC1009,1073
{% endif %}

set_up_rcon_and_ports_configuration() {
  # Normalize line endings to LF and remove options
  # so that we don't need to handle missing defaults
  config_without_socket_address_options=$(sed server.properties \
    -e 's/\r$//' \
    -e '/^[[:space:]]*server-port[[:space:]]*[=:]/d' \
    -e '/^[[:space:]]*query.port[[:space:]]*[=:]/d' \
    -e '/^[[:space:]]*rcon.password[[:space:]]*[=:]/d' \
    -e '/^[[:space:]]*enable-rcon[[:space:]]*[=:]/d' \
    -e '/^[[:space:]]*rcon.port[[:space:]]*[=:]/d' \
    -e '/^[[:space:]]*rcon.password[[:space:]]*[=:]/d' \
    2>/dev/null || true)

  # Write the server properties to a new file and atomically
  # rename it to prevent options from being corrupted on crash
  printf '%s
server-port={{ server_port }}
query.port={{ server_port }}
enable-rcon=true
rcon.port={{ rcon_port }}
rcon.password={{ rcon_password }}
' \
    "$config_without_socket_address_options" > server.properties$TEMPORARY_FILE_SUFFIX
  atomic_rename_successor_file server.properties

  # Ensure that rconctl has a server configured with the same credentials
  cat <<'RCON_CONF' > ~/.rcon.conf
[server]
host = localhost
port = {{ rcon_port }}
passwd = {{ rcon_password }}
RCON_CONF
}

is_current_mc_version_defined_and_different() {
  [ -n "$1" ] && [ "$mc_version" != "$last_mc_version" ]
}

# ---

# Clean up leftovers from in-progress file modifications done by us
rm -f -- *$TEMPORARY_FILE_SUFFIX
rm -f -- "$DATA_FOLDER"/*$TEMPORARY_FILE_SUFFIX

# Install signal handlers for server control
trap 'RESTARTING=1' PWR
trap 'touch "$BACKUP_AT_NEXT_START_FLAG_FILE" || true' USR1
trap 'touch "$UPDATE_AT_NEXT_START_FLAG_FILE" || true' USR2

echo "$$" > "$PID_FILE_PATH"

while true; do
  # Get the current and latest seen Minecraft server version.
  # Accept and ignore comments and anything beyond the first content line
  mc_version="$(sed '/^#/{d;n};1q' mc_version 2>/dev/null || true)"
  last_mc_version="$(cat "$LAST_MC_VERSION_FILE" 2>/dev/null || true)"

  # Handle backups
  if
    [ -f "$BACKUP_AT_NEXT_START_FLAG_FILE" ] ||
    is_current_mc_version_defined_and_different "$mc_version" "$last_mc_version"
  then
    send_notification \
      '⚙️ Starting backup' \
      'A backup has been scheduled for "{{ user }}" and is now in progress.' \
      295369

    # Prevent the log file from growing too big
    if tail -n 2000 "$BACKUP_LOG_FILE_PATH" 2>/dev/null > "$BACKUP_LOG_FILE_PATH$TEMPORARY_FILE_SUFFIX"; then
      atomic_rename_successor_file "$BACKUP_LOG_FILE_PATH"
    fi

    echo "$(date) Starting server backup" | tee -a "$BACKUP_LOG_FILE_PATH"

    backctl_output="$(mktemp --dry-run --tmpdir="$TRANSIENT_FILES_DIR" backctl_out.XXX)"
    mkfifo -m 'u=rw,g=,o=' "$backctl_output"
    tee -a "$BACKUP_LOG_FILE_PATH" < "$backctl_output" &

    unset backup_failed
    if is_current_mc_version_defined_and_different "$mc_version" "$last_mc_version"; then
      sudo backctl -i '{{ user }}' -d "$PWD" -e "$PWD/restart.sh" full_and_clear_all_incrementals
    else
      sudo backctl -i '{{ user }}' -d "$PWD" -e "$PWD/restart.sh" incremental
    fi > "$backctl_output" 2>&1 || backup_failed=1

    wait
    rm -f "$backctl_output"

    echo "$(date) Backup finished${backup_failed:+ with error status}" | tee -a "$BACKUP_LOG_FILE_PATH"

    if [ -z "$backup_failed" ]; then
      rm -f "$BACKUP_AT_NEXT_START_FLAG_FILE"
      send_notification \
        '✅ Backup successful' \
        'The scheduled backup for "{{ user }}" has been completed successfully.' \
        295369
    else
      send_notification \
        '❌ Backup failed' \
        'The scheduled backup for "{{ user }}" has failed. Designated administrator, please review the logs for troubleshooting.' \
        13187332
    fi
  fi

  # Handle server launcher download/update
  if
    # Initial server JAR download necessary
    ! [ -f 'purpur.jar' ] ||
    is_current_mc_version_defined_and_different "$mc_version" "$last_mc_version" ||
    # Do not update if we don't know the target Minecraft version
    { [ -n "$mc_version" ] && [ -f "$UPDATE_AT_NEXT_START_FLAG_FILE" ]; }
  then
    # Handle missing server JAR and Minecraft version file by using a hardcoded version
    # shellcheck disable=SC1083
    mc_version=${mc_version:-{{ default_minecraft_version }}}

    echo "$(date) Downloading latest Purpur launcher for $mc_version"

    # The same atomic replace trick as above.
    # Download errors are ignored to gracefully retry updating if remote errors
    # or version misconfiguration occurs
    if curl -o "purpur.jar$TEMPORARY_FILE_SUFFIX" "https://api.purpurmc.org/v2/purpur/$mc_version/latest/download"; then
      atomic_rename_successor_file 'purpur.jar'

      echo "$mc_version" > "$LAST_MC_VERSION_FILE"

      rm -f "$UPDATE_AT_NEXT_START_FLAG_FILE"
    fi
  fi

  # The server RCON configuration must be consistent with the contents of
  # ~/.rconf.conf for it to be externally manageable, or we might lose the
  # ability to stop it
  set_up_rcon_and_ports_configuration

  unset RESTARTING
  rm -f "$STOPPED_FLAG_FILE"

  status_code=0
  java '-Xmx{{ java_vm_memory }}' '-Xms{{ java_vm_memory }}' \
    -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions \
    -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 \
    -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 \
    -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true \
    --add-modules=jdk.incubator.vector \
    -jar purpur.jar || status_code=$?

  touch "$STOPPED_FLAG_FILE"

  echo "$(date) Server exited with status code $status_code"

  if [ -z "$RESTARTING" ]; then
    while
      echo "$(date) Press Enter to start, or type 'rollback' and press Enter to restore a backup"
      read -r action
      case "$action" in
        rollback)
          sudo backctl -i '{{ user }}' -d "$PWD" -e "$PWD/restart.sh" interactive_restore || true;;
        *) false;;
      esac
    do
      :
    done
  else
    echo "$(date) Restarting server in 5 seconds"
    unset RESTARTING
    sleep 5
  fi
done
