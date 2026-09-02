#!/usr/bin/env bash
#
# check_microservice.sh
# ---------------------
# Uses Ansible (ad-hoc command) to verify that the Go calculator
# microservice is running on the target host by checking its PID.
#
# Usage:
#   ./scripts/check_microservice.sh [inventory] [host]
#
# Defaults:
#   inventory = inventory/hosts.ini
#   host      = all hosts in the [calculator] group
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

INVENTORY="${1:-${PROJECT_DIR}/inventory/hosts.ini}"
PATTERN="${2:-calculator}"

ANSIBLE_CMD="$(command -v ansible || echo ansible)"

SERVICE_NAME="${SERVICE_NAME:-calculator}"

echo "==> Checking '${SERVICE_NAME}' PID status on '${PATTERN}' via Ansible..."

# Find the PID of the running microservice process.
# Returns rc=0 and prints the PID when running, rc=1 otherwise.
${ANSIBLE_CMD} "${PATTERN}" -i "${INVENTORY}" -a \
    "pgrep -x ${SERVICE_NAME}" || {
        echo "FAIL: '${SERVICE_NAME}' is NOT running (no PID found)." >&2
        exit 1
    }

echo "OK: '${SERVICE_NAME}' is running."
