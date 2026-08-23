#!/usr/bin/env bash

set -euo pipefail

TODAY=$(date +%Y-%m-%d)
BACKUP_DIR="./backup/conf/${TODAY}"
OUTPUT_FILE="${BACKUP_DIR}/env_data.txt"

mkdir -p "$BACKUP_DIR"

printenv | sort > "$OUTPUT_FILE"

echo "Environment variables stored in: ${OUTPUT_FILE}"
