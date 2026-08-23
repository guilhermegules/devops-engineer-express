#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <folder-to-backup>"
    exit 1
fi

SOURCE_DIR=$1

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: '$SOURCE_DIR' is not a directory"
    exit 1
fi

TODAY=$(date +%Y-%m-%d)
BACKUP_DIR="./backup/data/${TODAY}"
FOLDER_NAME=$(basename "$SOURCE_DIR")
ZIP_FILE="${FOLDER_NAME}_${TODAY}.zip"

mkdir -p "$BACKUP_DIR"

zip -r "${BACKUP_DIR}/${ZIP_FILE}" "$SOURCE_DIR"

echo "Backup created: ${BACKUP_DIR}/${ZIP_FILE}"
