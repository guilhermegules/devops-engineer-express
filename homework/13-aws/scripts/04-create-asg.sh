#!/usr/bin/env bash
# Prerequisite: bake the AMI first with Packer (see packer/ and the README).
#   AMI_ID=ami-xxx ./04-create-asg.sh
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
AMI_ID="${AMI_ID:?export AMI_ID=<baked-calculator-ami>}"
SG_ID="${SG_ID:?export SG_ID=<security-group-id>}"
KEY_NAME="${KEY_NAME:-}"
MIN=${MIN:-1}
MAX=${MAX:-3}
DESIRED=${DESIRED:-2}

# AWS discontinued creating new Launch Configurations on 2023-01-01.
# If create-launch-configuration fails, the script falls back to a Launch Template.
USE_LC=0
if aws autoscaling create-launch-configuration \
  --region "$REGION" \
  --launch-configuration-name calculator-lc \
  --image-id "$AMI_ID" \
  --instance-type t2.micro \
  --security-groups "$SG_ID" \
  ${KEY_NAME:+--key-name "$KEY_NAME"} \
  2>/dev/null; then
  USE_LC=1
else
  echo "warning: could not create a Launch Configuration (deprecated by AWS); using a Launch Template instead."
fi

VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault --query 'Vpcs[0].VpcId' --output text)
# Some emulators / accounts do not honor the isDefault filter; fall back to the first VPC.
if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
  VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --query 'Vpcs[0].VpcId' --output text)
fi
SUBNETS=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].SubnetId' --output text | paste -sd ',' -)

if [[ "$USE_LC" == 1 ]]; then
  aws autoscaling create-auto-scaling-group \
    --region "$REGION" \
    --auto-scaling-group-name calculator-asg \
    --launch-configuration-name calculator-lc \
    --min-size "$MIN" --max-size "$MAX" --desired-capacity "$DESIRED" \
    --vpc-zone-identifier "$SUBNETS" \
    --load-balancer-names calculator-elb \
    --health-check-type ELB \
    --health-check-grace-period 300
else
  LT_ID=$(aws ec2 create-launch-template \
    --region "$REGION" \
    --launch-template-name calculator-lt \
    --launch-template-data "{\"ImageId\":\"$AMI_ID\",\"InstanceType\":\"t2.micro\",\"SecurityGroupIds\":[\"$SG_ID\"]${KEY_NAME:+\",KeyName\":\"$KEY_NAME\"}}" \
    --query 'LaunchTemplate.LaunchTemplateId' --output text)

  aws autoscaling create-auto-scaling-group \
    --region "$REGION" \
    --auto-scaling-group-name calculator-asg \
    --launch-template "LaunchTemplateId=$LT_ID,Version=\$Latest" \
    --min-size "$MIN" --max-size "$MAX" --desired-capacity "$DESIRED" \
    --vpc-zone-identifier "$SUBNETS" \
    --load-balancer-names calculator-elb \
    --health-check-type ELB \
    --health-check-grace-period 300
fi

echo "Auto Scaling Group 'calculator-asg' created (min=$MIN max=$MAX desired=$DESIRED)."
echo "Test through the ELB:"
echo "  curl http://<ELB-DNS>/calc/sum/2/3"