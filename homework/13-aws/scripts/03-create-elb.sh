#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
SG_ID="${SG_ID:?export SG_ID=<security-group-id>}"
INSTANCE_ID="${INSTANCE_ID:?export INSTANCE_ID=<instance-id>}"
VPC_ID="${VPC_ID:-}"
SUBNET=${SUBNET:-}
if [[ -z "$SUBNET" ]]; then
  if [[ -z "$VPC_ID" ]]; then
    VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault --query 'Vpcs[0].VpcId' --output text)
    # Some emulators / accounts do not honor the isDefault filter; fall back to the first VPC.
    if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
      VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --query 'Vpcs[0].VpcId' --output text)
    fi
  fi
  SUBNET=$(
    aws ec2 describe-subnets --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC_ID" \
      --query 'Subnets[0].SubnetId' --output text
  )
fi

# 1. Separate security group for the load balancer (HTTP on 80 from anywhere)
ELB_SG=$(aws ec2 create-security-group \
  --region "$REGION" \
  --group-name calculator-elb-sg \
  --description "ELB for calculator microservice" \
  --query GroupId --output text)

aws ec2 authorize-security-group-ingress \
  --region "$REGION" \
  --group-id "$ELB_SG" \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

# 2. Create the (Classic) ELB: listeners 80 -> 8080
ELB_NAME=$(aws elb create-load-balancer \
  --region "$REGION" \
  --load-balancer-name calculator-elb \
  --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=8080" \
  --subnets "$SUBNET" \
  --security-groups "$ELB_SG" \
  --query DNSName --output text)

echo "Created ELB: $ELB_NAME"

# 3. Health check against the calculator endpoint
aws elb configure-health-check --region "$REGION" \
  --load-balancer-name calculator-elb \
  --health-check Target=HTTP:8080/calc/sum/1/2,Interval=30,Timeout=5,UnhealthyThreshold=2,HealthyThreshold=2

# 4. Register the instance
aws elb register-instances-with-load-balancer --region "$REGION" \
  --load-balancer-name calculator-elb \
  --instances "$INSTANCE_ID"

echo
echo "ELB DNS: $ELB_NAME"
echo "Test:    curl http://$ELB_NAME/calc/sum/2/3"