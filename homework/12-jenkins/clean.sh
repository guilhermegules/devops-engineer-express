#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${1:-calculator-microservice}"
CONTAINER_NAME="${2:-calculator-microservice}"

removeContainer() {
    if docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null | grep -q true; then
        echo "Stopping container '${CONTAINER_NAME}'..."
        docker stop "${CONTAINER_NAME}" >/dev/null
    fi
    if docker ps -a --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
        echo "Removing container '${CONTAINER_NAME}'..."
        docker rm "${CONTAINER_NAME}" >/dev/null
    fi
}

removeImage() {
    if docker image inspect "${IMAGE_NAME}:latest" >/dev/null 2>&1; then
        echo "Removing image '${IMAGE_NAME}:latest'..."
        docker rmi "${IMAGE_NAME}:latest" >/dev/null
    fi
}

removePackerPlugins() {
    local plugins_dir="${PACKER_PLUGIN_PATH:-${HOME}/.config/packer/plugins}"
    if [ -d "${plugins_dir}" ]; then
        echo "Removing Packer plugins cache '${plugins_dir}'..."
        rm -rf "${plugins_dir}"
    fi
}

removeContainer
removeImage
removePackerPlugins

echo "Cleanup complete."