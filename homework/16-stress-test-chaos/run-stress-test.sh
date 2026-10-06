#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:8080}"
USERS="${2:-100}"
RAMP_SECONDS="${3:-30}"
STEADY_SECONDS="${4:-60}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POM="${SCRIPT_DIR}/pom.xml"

if ! curl -sf --ipv4 --max-time 5 "${BASE_URL}/calc/history" >/dev/null; then
    echo "Microservice is not answering at ${BASE_URL}/calc/history, starting it..."
    if ! START_OUTPUT="$(APP_URL="${BASE_URL}" PORT="${BASE_URL##*:}" \
        "${SCRIPT_DIR}/manage-calculator.sh" up 2>&1)"; then
        printf '%s\n' "${START_OUTPUT}" >&2
        exit 1
    fi
    printf '%s\n' "${START_OUTPUT}"
    BASE_URL="$(printf '%s\n' "${START_OUTPUT}" | sed -n 's/^Calculator base URL: //p' | tail -1)"
fi

echo "Stress testing ${BASE_URL}/calc/history with ${USERS} users (${RAMP_SECONDS}s ramp, ${STEADY_SECONDS}s steady)..."
cd "${SCRIPT_DIR}"
mvn -B gatling:test \
    -DtargetUrl="${BASE_URL}" \
    -Dusers="${USERS}" \
    -DrampSeconds="${RAMP_SECONDS}" \
    -DsteadySeconds="${STEADY_SECONDS}"

REPORT="$(ls -td "${SCRIPT_DIR}"/target/gatling/*/ | head -1)index.html"
echo "Report: ${REPORT}"