#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

IMAGE_NAME="${IMAGE_NAME:-calculator-microservice:stress-test}"
CONTAINER_NAME="${CONTAINER_NAME:-calculator-stress-test}"
NETWORK_NAME="${NETWORK_NAME:-calculator-stress-test-net}"
PORT="${PORT:-8080}"
CONTAINER_PORT=8080
APP_URL_OVERRIDE="${APP_URL:-}"
APP_URL="${APP_URL_OVERRIDE:-http://localhost:${PORT}}"
DOCKERFILE="${REPO_ROOT}/homework/07-docker/Dockerfile"
BUILD_CONTEXT="${REPO_ROOT}"
URL_PREFIX="Calculator base URL: "
STATE_FILE="${SCRIPT_DIR}/.manage-calculator.state"

startCalculator() {
    loadState

    if [ "$(statusCalculator)" = "RUNNING" ]; then
        echo "Calculator is already RUNNING at ${APP_URL}"
        reportUrl
        return 0
    fi

    if [ -n "$(docker ps -aq -f "name=^${CONTAINER_NAME}$")" ]; then
        docker rm -f "${CONTAINER_NAME}" >/dev/null
    fi

    if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
        echo "Building image ${IMAGE_NAME} from ${DOCKERFILE}..."
        docker build -t "${IMAGE_NAME}" -f "${DOCKERFILE}" "${BUILD_CONTEXT}"
    fi

    resolveFreePort
    ensureNetwork

    echo "Starting calculator ${CONTAINER_NAME} on port ${PORT}..."
    docker run -d \
        --name "${CONTAINER_NAME}" \
        --network "${NETWORK_NAME}" \
        -p "${PORT}:${CONTAINER_PORT}" \
        --label "devops.homework=16-stress-test-chaos" \
        "${IMAGE_NAME}" >/dev/null

    waitForCalculator
    saveState
    reportUrl
}

ensureNetwork() {
    if docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
        return 0
    fi
    echo "Creating network ${NETWORK_NAME}..."
    docker network create "${NETWORK_NAME}" >/dev/null
}

portBusy() {
    (exec 3<>"/dev/tcp/127.0.0.1/${1}") >/dev/null 2>&1
}

describeHolder() {
    local holder
    holder="$(docker ps --filter "publish=${1}" --format '{{.Names}}' | grep -v "^${CONTAINER_NAME}$" || true)"
    if [ -n "${holder}" ]; then
        echo " (held by container: ${holder})"
    else
        echo " (held by another process)"
    fi
}

resolveFreePort() {
    local requested="${PORT}"
    local candidate="${PORT}"
    local scanned=0

    while portBusy "${candidate}"; do
        candidate=$((candidate + 1))
        scanned=$((scanned + 1))

        if [ "${scanned}" -ge 20 ]; then
            echo "No free port found in ${requested}..${candidate}." >&2
            return 1
        fi

        if [ "${scanned}" -eq 1 ]; then
            echo "Port ${requested} is busy$(describeHolder "${requested}"), falling back to ${candidate}."
        fi
    done

    PORT="${candidate}"
    APP_URL="http://localhost:${PORT}"
}

loadState() {
    if [ -n "${APP_URL_OVERRIDE}" ] || [ ! -r "${STATE_FILE}" ]; then
        return 0
    fi
    PORT="$(sed -n 's/^PORT=//p' "${STATE_FILE}")"
    APP_URL="$(sed -n 's/^APP_URL=//p' "${STATE_FILE}")"
}

saveState() {
    printf 'PORT=%s\nAPP_URL=%s\n' "${PORT}" "${APP_URL}" >"${STATE_FILE}"
}

clearState() {
    rm -f "${STATE_FILE}"
}

waitForCalculator() {
    local attempt
    for attempt in $(seq 1 30); do
        if probeEndpoint; then
            echo "Calculator is answering at ${APP_URL}/calc/history"
            return 0
        fi
        sleep 1
    done
    echo "Calculator did not answer at ${APP_URL}/calc/history" >&2
    echo "Check ./manage-calculator.sh logs" >&2
    return 1
}

probeEndpoint() {
    curl -fsS --ipv4 --max-time 2 "${APP_URL}/calc/history" >/dev/null 2>&1
}

reportUrl() {
    echo "${URL_PREFIX}${APP_URL}"
}

stopCalculator() {
    loadState

    if [ "$(statusCalculator)" = "NOT RUNNING" ]; then
        echo "Calculator is NOT RUNNING"
        clearState
        return 0
    fi
    echo "Stopping calculator ${CONTAINER_NAME}..."
    docker rm -f "${CONTAINER_NAME}" >/dev/null
    docker network rm "${NETWORK_NAME}" >/dev/null 2>&1 || true
    clearState
    echo "Calculator stopped."
}

statusCalculator() {
    if [ "$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null)" = "true" ]; then
        echo "RUNNING"
    else
        echo "NOT RUNNING"
    fi
}

showStatus() {
    loadState
    echo "Container ${CONTAINER_NAME}: $(statusCalculator)"
    if health="$(curl -fsS --ipv4 --max-time 5 "${APP_URL}/calc/history" 2>/dev/null)"; then
        echo "Endpoint ${APP_URL}/calc/history: OK (${#health} bytes)"
    else
        echo "Endpoint ${APP_URL}/calc/history: NOT ANSWERING"
    fi
}

showLogs() {
    docker logs --tail=100 -f "${CONTAINER_NAME}" "$@"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") {up|down|status|restart|logs|help}

Commands:
  up        Build (if needed) and start the calculator, then wait until
            /calc/history answers. A busy host port is skipped and the next
            free one is used instead
  down      Stop and remove the calculator container and its network
  status    Show the container state and whether the endpoint answers
  restart   Stop and start the calculator again, wiping the in memory history
  logs      Follow the calculator logs
  help      Show this message

Environment:
  PORT              First host port to try (default: ${PORT})
  APP_URL           Base URL used for the readiness check (default: ${APP_URL})
  IMAGE_NAME        Image tag to build and run (default: ${IMAGE_NAME})
  CONTAINER_NAME    Container name (default: ${CONTAINER_NAME})
  NETWORK_NAME      Bridge network for the container (default: ${NETWORK_NAME})

The port picked by "up" is kept in ${STATE_FILE##*/} so status, logs and down
keep pointing at the same service. run-stress-test.sh calls "up" when the
endpoint is down and reads the port from the "${URL_PREFIX}" line it prints.
EOF
}

case "${1:-}" in
    up)      startCalculator ;;
    down)    stopCalculator ;;
    status)  showStatus ;;
    restart) stopCalculator; startCalculator ;;
    logs)    shift; showLogs "$@" ;;
    help|-h|--help) usage ;;
    *)       usage; exit 1 ;;
esac