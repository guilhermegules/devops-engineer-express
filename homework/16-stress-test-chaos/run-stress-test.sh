#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:8080}"
USERS="${2:-100}"
RAMP_SECONDS="${3:-30}"
STEADY_SECONDS="${4:-60}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POM="${SCRIPT_DIR}/pom.xml"

if ! curl -sf --max-time 5 "${BASE_URL}/calc/history" >/dev/null; then
    echo "Microservice is not answering at ${BASE_URL}/calc/history"
    echo "Start it first, e.g. ../12-jenkins/launch.sh or ../07-docker/manage-calculator.sh start"
    exit 1
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