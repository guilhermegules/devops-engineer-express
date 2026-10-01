#!/usr/bin/env bash
# send-requests.sh — drive traffic through the calculator so collectd has
# something to report and Elasticsearch has documents to store.
#
# Usage: ./send-requests.sh [REQUESTS]   (default: 20)
set -euo pipefail

APP_URL="${APP_URL:-http://localhost:8080}"
REQUESTS="${1:-20}"

operations=(sum sub mul div)

call_calculator() {
    local op="$1" a="$2" b="$3"
    curl -fsS -o /dev/null --max-time 5 "${APP_URL}/calc/${op}/${a}/${b}"
}

echo "Sending ${REQUESTS} requests to ${APP_URL}..."
for i in $(seq 1 "${REQUESTS}"); do
    op="${operations[$((i % ${#operations[@]}))]}"
    call_calculator "${op}" "$((i + 1))" "$((i % 7 + 2))"
    printf '.'
done
echo

echo
echo "Operations recorded by the microservice:"
curl -fsS --max-time 5 "${APP_URL}/calc/history" | head -c 400
echo
echo
echo "collectd samples the service every 10s, so give it one interval before"
echo "running ./verify-telemetry.sh."
