#!/usr/bin/env bash
# 01-create-security-group.sh — Create the Security Group for the calculator.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"

SG_ID=$(aws ec2 create-security-group \
  --region "$REGION" \
  --group-name calculator-sg \
  --description "Allow SSH and calculator microservice traffic" \
  --query GroupId --output text)

echo "Created Security Group: $SG_ID"

aws ec2 authorize-security-group-ingress \
  --region "$REGION" \
  --group-id "$SG_ID" \
  --protocol tcp --port 22 --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --region "$REGION" \
  --group-id "$SG_ID" \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0

echo "Security Group $SG_ID now allows TCP 22 (SSH) and TCP 8080 (app)."
echo "Save this id; the next scripts expect it in SG_ID."