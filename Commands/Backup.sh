#!/bin/bash
# -----------------------------------------------------------------------------
# Backup Helper with options:
#  -p, -path         Set and save default output path for session (must be a directory)
#  -r, -relative     Use relative path inside backup dir (starts with hostname)
#  -n, -new          New copy (timestamped if exists)
#  -o, -overwrite    Overwrite without confirmation
#  -d, -debug        Debug mode (show commands, no copy)
#  -x, -reset        Reset default path to /home/<user>/Backups
#  -h, -help         Show this help summary
#
#  -github, -link, -url, -web         to open https://github.com/cmdrFRANKLY1 
# -----------------------------------------------------------------------------

CONFIG_FILE="$HOME/.config/backup.conf"
: "${SESSION_BACKUP_DIR:=}"

# Temp var to hold destination during copy for cleanup
TMP_DEST=""

# Cleanup function for partial backups on Ctrl+C
cleanup() {
  if [ -n "$TMP_DEST" ] && [ -e "$TMP_DEST" ]; then
    echo -e "\nBackup interrupted! Cleaning up partial backup at: $TMP_DEST"
    rm -rf "$TMP_DEST"
  fi
  exit 130
}

trap cleanup SIGINT

show_help() {
  cat << EOF
Usage: backup [options] <source>

Options:
  -p, -path <dir>      Set and save default backup directory (must be a directory)
  -r, -relative        Use relative path inside backup directory (prepends hostname)
  -n, -new             Create new timestamped copy if destination exists
  -o, -overwrite       Overwrite existing backup without confirmation
  -d, -debug           Show commands without performing backup
  -x, -reset           Reset default backup directory to ~/Backups
  -h, -help            Show this help summary and exit
  
  -github, -link, -url, -web          Open https://github.com/cmdrFRANKLY1 
EOF
}

# Load default path from config if not set
if [ -z "$SESSION_BACKUP_DIR" ] && [ -f "$CONFIG_FILE" ]; then
  SESSION_BACKUP_DIR=$(grep '^defaultBackupPath=' "$CONFIG_FILE" | cut -d'=' -f2-)
fi

# If no config, prompt user to create it
if [ -z "$SESSION_BACKUP_DIR" ] && [ ! -f "$CONFIG_FILE" ]; then
  DEFAULT_DIR="/home/$(whoami)/Backups"
  read -rp "No default backup directory found. Use '$DEFAULT_DIR' as default? [y/N]: " confirm
  case "$confirm" in
    [yY][eE][sS]|[yY])
      mkdir -p "$(dirname "$CONFIG_FILE")"
      echo "defaultBackupPath=$DEFAULT_DIR" > "$CONFIG_FILE"
      SESSION_BACKUP_DIR="$DEFAULT_DIR"
      echo "Default backup path set to: $SESSION_BACKUP_DIR"
      ;;
    *)
      echo "Aborted. Please set a path using: backup -p /path/to/backups/"
      return 1
      ;;
  esac
fi

backup() {
  local RELATIVE=false
  local NEW_COPY=false
  local OVERWRITE=false
  local DEBUG=false

  # Parse options
  while [[ "$1" == -* ]]; do
    case "$1" in
      -h|-help)
        show_help
        return 0
        ;;
      -p|-path)
        shift
        if [ -z "$1" ]; then
          echo "Error: -p/-path requires a directory path"
          return 1
        fi
        if [ ! -d "$1" ]; then
          echo "Error: '$1' is not a directory."
          return 1
        fi
        SESSION_BACKUP_DIR="$1"
        mkdir -p "$(dirname "$CONFIG_FILE")"
        echo "defaultBackupPath=$SESSION_BACKUP_DIR" > "$CONFIG_FILE"
        echo "Default backup path set to: $SESSION_BACKUP_DIR"
        return 0
        ;;
      -x|-reset)
        SESSION_BACKUP_DIR="/home/$(whoami)/Backups"
        mkdir -p "$(dirname "$CONFIG_FILE")"
        echo "defaultBackupPath=$SESSION_BACKUP_DIR" > "$CONFIG_FILE"
        echo "Default backup path reset to: $SESSION_BACKUP_DIR"
        return 0
        ;;
      -github|-link|-url|-web)
        read -rp "Open https://github.com/cmdrFRANKLY1 in your default browser? [y/N]: " confirm
        case "$confirm" in
          [yY][eE][sS]|[yY])
            if command -v xdg-open >/dev/null 2>&1; then
              xdg-open "https://github.com/cmdrFRANKLY1"
              return 0
            else
              echo "Error: 'xdg-open' not found. Cannot open URL."
              return 1
            fi
            ;;
          *)
            echo "Cancelled opening URL."
            return 0
            ;;
        esac
        ;;
      -r|-relative) RELATIVE=true ;;
      -n|-new) NEW_COPY=true ;;
      -o|-overwrite) OVERWRITE=true ;;
      -d|-debug) DEBUG=true ;;
      *)
        echo "Unknown option: $1"
        return 1
        ;;
    esac
    shift
  done

  local SOURCE="$1"
  if [ -z "$SOURCE" ]; then
    echo "Error: No source specified."
    return 1
  fi
  if [ ! -e "$SOURCE" ]; then
    echo "Error: Source '$SOURCE' does not exist."
    return 1
  fi

  local ABS_SOURCE
  ABS_SOURCE=$(realpath -e -- "$SOURCE") || { echo "Error: Cannot resolve source path."; return 1; }
  local BASENAME
  BASENAME=$(basename -- "$ABS_SOURCE")

  # Determine destination path early
  local DEST
  if $RELATIVE; then
    local REL_PATH
    REL_PATH=$(realpath --relative-to="/" -- "$ABS_SOURCE")
    local HOSTNAME
    HOSTNAME=$(hostname)
    DEST="$SESSION_BACKUP_DIR/$HOSTNAME/$REL_PATH"
  else
    DEST="$SESSION_BACKUP_DIR/$BASENAME"
  fi

  # Prevent source and destination being the same path
  local ABS_DEST
  ABS_DEST=$(realpath -m -- "$DEST") || { echo "Error: Cannot resolve destination path."; return 1; }
  if [ "$ABS_SOURCE" = "$ABS_DEST" ]; then
    echo "Error: Source and destination are the same path. Backup aborted."
    return 1
  fi

  # Check if destination is writable or creatable
  if ! mkdir -p "$(dirname -- "$ABS_DEST")" 2>/dev/null; then
    echo "Error: Cannot create destination directory: $(dirname -- "$ABS_DEST")"
    return 1
  fi
  if [ ! -w "$(dirname -- "$ABS_DEST")" ]; then
    echo "Error: Destination directory is not writable: $(dirname -- "$ABS_DEST")"
    return 1
  fi

  # Show size
  local SIZE
  SIZE=$(du -sh -- "$ABS_SOURCE" 2>/dev/null | cut -f1)
  echo "Size of source: $SIZE"

  # Confirm if source is a directory
  if [ -d "$ABS_SOURCE" ] && ! $OVERWRITE; then
    read -rp "Source is a directory. Proceed with backup? [y/N]: " confirm
    case "$confirm" in
      [yY][eE][sS]|[yY]) ;;
      *)
        echo "Backup aborted."
        return 1
        ;;
    esac
  fi

  # Confirm before overwriting directories even with -o
  if [ -d "$ABS_DEST" ]; then
    if $NEW_COPY; then
      local TIMESTAMP
      TIMESTAMP=$(date +%Y%m%d_%H%M%S)
      DEST="${ABS_DEST%/}_$TIMESTAMP"
      echo "Creating new timestamped backup directory: $DEST"
    else
      read -rp "Directory exists at $ABS_DEST. Overwrite? [y/N]: " confirm
      case "$confirm" in
        [yY][eE][sS]|[yY]) ;;
        *)
          echo "Aborted. Directory not overwritten."
          return 1
          ;;
      esac
    fi
  fi

  # Confirm before overwriting files if no -o and no -n
  if [ -f "$ABS_DEST" ]; then
    if $NEW_COPY; then
      local TIMESTAMP
      TIMESTAMP=$(date +%Y%m%d_%H%M%S)
      DEST="${ABS_DEST%.*}_$TIMESTAMP.${ABS_DEST##*.}"
      echo "Creating new timestamped backup file: $DEST"
    elif ! $OVERWRITE; then
      read -rp "File exists at $ABS_DEST. Overwrite? [y/N]: " confirm
      case "$confirm" in
        [yY][eE][sS]|[yY]) ;;
        *)
          echo "Aborted. File not overwritten."
          return 1
          ;;
      esac
    fi
  fi

  local CMD="cp -a --no-preserve=ownership -- \"$ABS_SOURCE\" \"$DEST\""

  TMP_DEST="$DEST"  # For cleanup trap

  local START_TIME
  START_TIME=$(date +%s.%N)

  if $DEBUG; then
    echo "[DEBUG] Command: $CMD"
  else
    eval $CMD
    local END_TIME
    END_TIME=$(date +%s.%N)
    local ELAPSED
    ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)
    echo
    printf "\tBackup created in %.3f Seconds\n" "$ELAPSED"
    printf "\tSource: %s with %s\n" "$ABS_SOURCE" "$SIZE"
    printf "\tDestination: %s\n" "$DEST"
    echo
  fi

  TMP_DEST=""  # Clear tmp var on successful finish
}

bckp() { backup "$@"; }
