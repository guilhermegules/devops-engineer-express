#!/usr/bin/env bash

IMAGE_NAME="calculator-microservice"
CONTAINER_NAME="calculator-microservice"
PORT=8080
HOMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_CONTEXT="$(dirname "$HOMEWORK_DIR")"

buildImage() {
    echo "Building image ${IMAGE_NAME}..."
    docker build -t "${IMAGE_NAME}" -f "${HOMEWORK_DIR}/Dockerfile" "${BUILD_CONTEXT}"
}

startMicroservice() {
    if [ "$(statusMicroservice)" = "RUNNING" ]; then
        echo "Microservice is already RUNNING"
        return 0
    fi

    if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
        buildImage
    fi

    echo "Starting microservice ${CONTAINER_NAME}..."
    docker run -d --name "${CONTAINER_NAME}" -p "${PORT}:${PORT}" "${IMAGE_NAME}"
    echo "Microservice started. URL: http://localhost:${PORT}/calc/sum/2/3"
}

stopMicroservice() {
    if [ "$(statusMicroservice)" = "RUNNING" ]; then
        echo "Stopping microservice ${CONTAINER_NAME}..."
        docker stop "${CONTAINER_NAME}" >/dev/null
        docker rm "${CONTAINER_NAME}" >/dev/null
        echo "Microservice stopped."
    else
        echo "Microservice is NOT RUNNING"
    fi
}

statusMicroservice() {
    local state
    state="$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null)"

    if [ "${state}" = "true" ]; then
        echo "RUNNING"
    else
        echo "NOT RUNNING"
    fi
}

usage() {
    cat <<EOF
Usage: $(basename "$0") {start|stop|status|restart}

Commands:
  start    Build (if needed) and start the microservice container
  stop     Stop and remove the microservice container
  status   Show whether the microservice is RUNNING or NOT RUNNING
  restart  Restart the microservice
EOF
}

case "${1:-}" in
    start)   startMicroservice ;;
    stop)    stopMicroservice ;;
    status)  statusMicroservice ;;
    restart) stopMicroservice; startMicroservice ;;
    *)       usage ;;
esac
