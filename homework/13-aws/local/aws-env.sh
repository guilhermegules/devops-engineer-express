#!/usr/bin/env bash
# floci emulator instead of real AWS. No account, no credentials needed.
#
#   source aws-env.sh
#   aws ec2 describe-instances
#   terraform apply
#
# Unset with:
#   unset AWS_ENDPOINT_URL AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION AWS_REGION
set -euo pipefail

export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_REGION="us-east-1"
unset AWS_PROFILE 2>/dev/null || true

echo "AWS tooling now targets floci at ${AWS_ENDPOINT_URL} (region ${AWS_REGION})."
echo "Start the emulator with: docker compose -f local/docker-compose.yml up -d"