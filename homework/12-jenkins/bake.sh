#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKER_FILE="${SCRIPT_DIR}/packer/calculator.pkr.hcl"
IMAGE_NAME="${1:-calculator-microservice}"
TAG="${2:-latest}"

echo "Initializing Packer plugins..."
packer init "${PACKER_FILE}"

echo "Baking Docker image '${IMAGE_NAME}:${TAG}' with Packer..."
packer build -var "image_name=${IMAGE_NAME}" -var "tag=${TAG}" "${PACKER_FILE}"

echo "Done. Image '${IMAGE_NAME}:${TAG}' is ready."
docker image ls "${IMAGE_NAME}"
