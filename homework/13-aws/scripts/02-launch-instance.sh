#!/usr/bin/env bash
# Pick an Ubuntu 22.04 AMI for your region, then run:
#   SG_ID=sg-xxx AMI_ID=ami-xxx ./02-launch-instance.sh
# or fill them in below and just run the script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REGION="${AWS_REGION:-us-east-1}"
AMI_ID="${AMI_ID:?export AMI_ID=<ubuntu-22.04-image>}"
SG_ID="${SG_ID:?export SG_ID=<security-group-id>}"
KEY_NAME="${KEY_NAME:-}"   # optional, pass -e KEY_NAME=.. for SSH access

INSTANCE_ID=$(aws ec2 run-instances \
  --region "$REGION" \
  --image-id "$AMI_ID" \
  --instance-type t2.micro \
  ${KEY_NAME:+--key-name "$KEY_NAME"} \
  --security-group-ids "$SG_ID" \
  --user-data "file://${SCRIPT_DIR}/../user-data.sh" \
  --query 'Instances[0].InstanceId' --output text)

echo "Started instance: $INSTANCE_ID"

aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"

IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Instance $INSTANCE_ID running. Public IP: $IP"
echo "Source code must be present on the instance before user-data builds."

# Upload the microservice source, then build/start via SSH if KEY_NAME was given:
#   scp -i ~/Downloads/kp_devops_test.pem homework/06-go/* ubuntu@$IP:/tmp/calculator/
#   ssh  -i ~/Downloads/kp_devops_test.pem ubuntu@$IP \
#         'sudo mkdir -p /tmp/calculator && sync && sudo bash /var/lib/cloud/instance/scripts/part-001'
#
# Simplest alternative: baking the AMI first (Task 3), then launching from it,
# which already contains the built binary and boot service.