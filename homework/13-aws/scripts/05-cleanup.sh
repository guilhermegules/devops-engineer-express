#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"

echo "-> Deleting Auto Scaling Group..."
aws autoscaling delete-auto-scaling-group --region "$REGION" \
  --auto-scaling-group-name calculator-asg --force-delete || true

echo "-> Deleting Launch Configuration / Launch Template..."
aws autoscaling delete-launch-configuration --region "$REGION" \
  --launch-configuration-name calculator-lc || true
aws ec2 delete-launch-template --region "$REGION" \
  --launch-template-name calculator-lt || true

echo "-> Deleting instances with tag Name=calculator-instance..."
for id in $(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[].Instances[?Tags[?Key==`Name` && Value==`calculator-instance`]].InstanceId' \
  --output text); do
  aws ec2 terminate-instances --region "$REGION" --instance-ids "$id" >/dev/null
done

echo "-> Deleting ELB..."
aws elb delete-load-balancer --region "$REGION" --load-balancer-name calculator-elb || true

echo "-> Deleting Security Groups..."
ELB_SG=$(aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=group-name,Values=calculator-elb-sg" \
  --query 'SecurityGroups[0].GroupId' --output text)
[[ "$ELB_SG" == "None" ]] || aws ec2 delete-security-group --region "$REGION" --group-id "$ELB_SG" || true

APP_SG=$(aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=group-name,Values=calculator-sg" \
  --query 'SecurityGroups[0].GroupId' --output text)
[[ "$APP_SG" == "None" ]] || aws ec2 delete-security-group --region "$REGION" --group-id "$APP_SG" || true

echo "Cleanup complete."