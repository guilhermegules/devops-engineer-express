#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${1:-calculator-microservice}"
CONTAINER_NAME="${2:-calculator-microservice}"
PORT="${3:-8080}"

stopContainer() {
    if docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null | grep -q true; then
        echo "Stopping existing container '${CONTAINER_NAME}'..."
        docker stop "${CONTAINER_NAME}" >/dev/null
        docker rm   "${CONTAINER_NAME}" >/dev/null
    fi
}

startContainer() {
    if ! docker image inspect "${IMAGE_NAME}:latest" >/dev/null 2>&1; then
        echo "Image '${IMAGE_NAME}:latest' not found. Run bake.sh first."
        exit 1
    fi

    echo "Starting container '${CONTAINER_NAME}' on port ${PORT}..."
    docker run -d --name "${CONTAINER_NAME}" -p "${PORT}:${PORT}" "${IMAGE_NAME}:latest"
    echo "Microservice deployed at http://localhost:${PORT}/calc/sum/2/3"
}

stopContainer
startContainer
