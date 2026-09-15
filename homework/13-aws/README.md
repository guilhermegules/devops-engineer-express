# Homework 13 - AWS

Deploy the **Go calculator microservice** (from `../06-go`) on **Amazon Web Services**: launch a `t2.micro` instance, put an Elastic Load Balancer (ELB) in front of it, bake an Amazon Machine Image (AMI) with **Packer**, then scale it out with an **Auto Scaling Group** built from a **Launch Configuration**.

Everything is driven with the **AWS CLI**, **Packer**, and (bonus) **Terraform**.

Following the assignment (see `13-AWS.txt`):

| # | Task | Solved with |
|---|---|---|
| 1 | Create a `t2.micro` on AWS and install the Go microservice there | `user-data.sh` + `scripts/02-launch-instance.sh` |
| 2 | Create an ELB and point it at the EC2 instance | `scripts/03-create-elb.sh` |
| 3 | Bake an AWS image with Packer of the Go microservice | `packer/calculator-ami.pkr.hcl` |
| 4 | Create one ASG/LC for the microservice using the baked image | `scripts/04-create-asg.sh` |
| 5 | **Bonus**: launch ASG/LC/ELB using Terraform | `terraform/` (Launch Template + ASG + Classic ELB) |

> You can run **everything locally with no AWS account** using **floci**, the free AWS emulator — see the *[Run it locally (no AWS)](#run-it-locally-no-aws-floci)* section.

## Files

| File | Description |
|---|---|
| `user-data.sh` | Bootstrap script (user data) that installs Go, builds the microservice, and registers a systemd unit |
| `packer/calculator-ami.pkr.hcl` | Packer template (`amazon-ebs` builder) that bakes an AMI with the microservice pre-installed |
| `packer/provision-calculator.sh` | Packer shell provisioner: installs Go, builds the binary, installs the systemd unit |
| `scripts/01-create-security-group.sh` | Creates the app Security Group (SSH 22 + app 8080) |
| `scripts/02-launch-instance.sh` | Task 1: launches the `t2.micro` with `user-data.sh` |
| `scripts/03-create-elb.sh` | Task 2: creates the Classic ELB (80 → 8080), health check, registers the instance |
| `scripts/04-create-asg.sh` | Task 4: creates the Launch Configuration + Auto Scaling Group from the baked AMI |
| `scripts/05-cleanup.sh` | Removes the ASG, LC, ELB, instances, and Security Groups |
| `terraform/main.tf` | Task 5 (bonus): provider, security groups, load balancer, Launch Template + ASG (Classic ELB on AWS, ALB against floci) |
| `terraform/variables.tf` | Tunable inputs (`instance_type`, capacities, optional `ami_id`/`key_name`/`endpoint_url`) |
| `terraform/outputs.tf` | Load balancer DNS name, AMI id, and a ready-to-run `curl` test command |
| `terraform/versions.tf` | Pins Terraform >= 1.5 and the AWS provider (>= 5) |
| `terraform/terraform.tfvars.example` | Sample values, copy to `terraform.tfvars` |
| `local/docker-compose.yml` | Runs the **floci** AWS emulator on `localhost:4566` (no AWS account needed) |
| `local/aws-env.sh` | Sources the env vars that point the AWS CLI / Terraform at floci |
| `13-AWS.txt` | The homework assignment statement |

## Prerequisites

- An [AWS account](https://aws.amazon.com/) with credentials configured (`aws configure` or env vars `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION`) — **not needed** for the local floci path
- [Docker](https://docs.docker.com/get-started/get-docker/) with Compose — only for the local floci path
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (`aws --version`)
- [Packer](https://developer.hashicorp.com/packer/downloads) (`packer -v`)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) only for the Task 5 bonus (`terraform version`)
- A [Go 1.21+](https://go.dev/dl/) toolchain only if you build the binary locally (optional)
- An SSH key pair in your AWS account (and the `.pem` file locally) if you want SSH access

> The microservice is tiny (single file, standard library only), so everything runs comfortably on a `t2.micro`.

> Every script reads `AWS_REGION` from the environment and defaults to `us-east-1`.

---

## Run it locally (no AWS) — floci

[**floci**](https://floci.io) is a free, open-source **AWS emulator** (drop-in LocalStack alternative). It serves the AWS API on `localhost:4566` with fake credentials and **no AWS account** — so tasks 1, 2, 4 and the bonus task 5 all run on your machine.

> **Local vs real**: EC2, classic ELB, launch templates and autoscaling are all emulated, but **Packer cannot target a custom endpoint**, so baking the AMI (Task 3) stays a *real-AWS* step. Locally you simply reuse floci's pre-seeded image (`ami-0abcdef1234567890`).

### 1. Start the emulator

```bash
cd homework/13-aws
docker compose -f local/docker-compose.yml up -d

# wait for "healthy", then sanity check
curl http://localhost:4566/_localstack/health
```

### 2. Point your tools at it

```bash
source local/aws-env.sh
# -> sets AWS_ENDPOINT_URL=http://localhost:4566 + fake credentials (test/test)
```

Now `aws`, `terraform`, boto3, … talk to floci. Continue with the normal tasks below; the only difference is **any** AMI id works — use floci's built-in `ami-0abcdef1234567890`.

```bash
# Tasks 1, 2, 4 (the scripts handle the fake credentials and default VPC):
chmod +x scripts/*.sh
scripts/01-create-security-group.sh
SG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=calculator-sg --query 'SecurityGroups[0].GroupId' --output text)
AMI_ID=ami-0abcdef1234567890 SG_ID=$SG_ID scripts/02-launch-instance.sh
INSTANCE_ID=$(aws ec2 describe-instances --query 'Reservations[0].Instances[0].InstanceId' --output text)
SG_ID=$SG_ID INSTANCE_ID=$INSTANCE_ID scripts/03-create-elb.sh
AMI_ID=ami-0abcdef1234567890 SG_ID=$SG_ID MIN=1 MAX=2 DESIRED=1 scripts/04-create-asg.sh

# Task 5 (bonus) with Terraform — the module detects floci via endpoint_url and
# provisions an ALB (floci's classic-ELB can't be read back by the aws_elb provider):
cd terraform
terraform init
terraform apply -var endpoint_url=http://localhost:4566 \
                -var ami_id=ami-0abcdef1234567890 -auto-approve
```

Clean everything up when done:

```bash
source local/aws-env.sh && scripts/05-cleanup.sh   # remove CLI-created resources
cd terraform && terraform destroy -var endpoint_url=http://localhost:4566 -var ami_id=ami-0abcdef1234567890
docker compose -f local/docker-compose.yml down    # stop floci
```

### floci notes & quirks

- The emulator ignores `--filters Name=isDefault` on VPCs (scripts handle this with a fallback to the first VPC).
- `floci` supports Launch Configurations, so `scripts/04-create-asg.sh` may use the **LC** path instead of the Launch-Template fallback.
- The classic **`aws_elb`** Terraform resource can't read floci ELBs back (floci omits the source security-group the provider looks up), so **local Terraform mode automatically switches to an Application Load Balancer** (`aws_lb` + target group + listener). On real AWS the module keeps the classic ELB from the homework.
- The emulator persists state in `local/data/`; `docker compose -f local/docker-compose.yml down -v` wipes it for a truly fresh run.
- The `latest-compat` floci image also bundles the AWS CLI + boto3 (handy in CI).

---

## Launch a t2.micro and install the microservice

The microservice listens on port `8080`, so this homework uses an **Ubuntu 22.04** base image plus the bootstrap script `user-data.sh`.

```bash
# 1. Start in this directory
cd homework/13-aws

# 2. Security group (SSH 22 + app 8080)
chmod +x scripts/*.sh
scripts/01-create-security-group.sh      # prints and saves SG_ID

# 3. Launch the instance; set the Ubuntu 22.04 AMI id for your region
SG_ID=sg-xxxx AMI_ID=ami-<ubuntu-22.04> scripts/02-launch-instance.sh
```

The script launches a `t2.micro`, waits for it to be `running`, and prints its public IP.

**Getting the source onto the instance.** `user-data.sh` builds `/tmp/calculator`, so the source files (`go.mod`, `main.go` from `../06-go`) must be present. With a key pair configured (`KEY_NAME=...`), upload and build them:

```bash
scp -i ~/Downloads/kp_devops.pem homework/06-go/* ubuntu@<INSTANCE_IP>:/tmp/calculator/
ssh  -i ~/Downloads/kp_devops.pem ubuntu@<INSTANCE_IP> 'cd /tmp/calculator && export PATH=/usr/local/go/bin:$PATH && go build -o calculator main.go && sudo mkdir -p /opt/calculator && sudo cp calculator go.mod main.go /opt/calculator/ && sudo systemctl start calculator'
```

> **Recommended alternative:** skip the manual build entirely by launching straight from the Packer-baked AMI from Task 3 — those images already contain the compiled binary and the boot service.

Verify once the instance is running:

```bash
curl http://<INSTANCE_IP>:8080/calc/sum/2/3
curl http://<INSTANCE_IP>:8080/calc/history
```

## ELB in front of the instance

A Classic Elastic Load Balancer distributes traffic and health-checks the instances.

```bash
SG_ID=sg-xxxx INSTANCE_ID=<instance-id> scripts/03-create-elb.sh
```

This script:

1. Creates a dedicated ELB Security Group (HTTP on 80).
2. Creates `calculator-elb` with a listener `80 → 8080`.
3. Configures the health check against the calculator endpoint (`HTTP:8080/calc/sum/1/2`).
4. Registers your instance.

Test through the LB:

```bash
curl http://<ELB-DNS>/calc/sum/2/3    # e.g. calculator-elb-1234567890.us-east-1.elb.amazonaws.com
```

Manual equivalents are shown in `scripts/03-create-elb.sh` if you prefer the console.

## Bake an AWS image (AMI) with Packer

`packer/calculator-ami.pkr.hcl` uses the `amazon-ebs` builder: it boots a fresh **Ubuntu 22.04** `t2.micro`, uploads the microservice source (`../06-go`) via a file provisioner, runs `provision-calculator.sh` to install Go + build + register the systemd service, then snapshots the disk into an AMI.

```bash
cd homework/13-aws/packer

packer init calculator-ami.pkr.hcl      # installs the amazon plugin
packer fmt calculator-ami.pkr.hcl
packer validate calculator-ami.pkr.hcl
packer build calculator-ami.pkr.hcl
```

Note the AMI id Packer prints at the end (`ami-1234…`); you will need it for Task 4. Overridable variables:

```bash
packer build -var aws_region=eu-west-1 -var instance_type=t3.micro calculator-ami.pkr.hcl
```

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | Region where the AMI is baked |
| `ami_name` | `calculator-microservice` | AMI name prefix (`-<timestamp>` is appended) |
| `instance_type` | `t2.micro` | Build instance type |

Because the systemd unit is `enable`d during the bake (not started), an instance launched from the AMI automatically serves the microservice on boot at port `8080`.

### Testing the AMI

```bash
aws ec2 run-instances --image-id ami-<baked> --instance-type t2.micro \
  --security-group-ids <calculator-sg> --subnet-id <SUBNET_ID>
curl http://<NEW_INSTANCE_IP>:8080/calc/sum/2/3
```

## ASG/LC with the baked image (AWS CLI)

`scripts/04-create-asg.sh` creates the **Launch Configuration** from your baked AMI and the **Auto Scaling Group** wired to the ELB from Task 2 — no Terraform needed.

```bash
SG_ID=sg-xxxx AMI_ID=ami-<baked> scripts/04-create-asg.sh
# optional sizing:  MIN=1 MAX=3 DESIRED=2 AMI_ID=... ./04-create-asg.sh
```

The script:

1. Creates the Launch Configuration `calculator-lc` (`t2.micro`, app Security Group, baked AMI).
2. Resolves the default VPC subnets.
3. Creates `calculator-asg` with the LC, `min/max/desired` capacity, attached to the ELB (`load-balancer-names` + `ELB` health check).

Try the scaling features:

```bash
# Simulate an instance crash; the ASG replaces it automatically
aws autoscaling terminate-instance-in-auto-scaling-group \
  --instance-id <INSTANCE_ID> --should-decrement-desired-capacity

# Watch instance counts
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names calculator-asg
aws autoscaling describe-auto-scaling-instances

# Bump the desired capacity
aws autoscaling set-desired-capacity --auto-scaling-group-name calculator-asg \
  --desired-capacity 4

curl http://<ELB-DNS>/calc/sum/2/3   # still works through the LB
```

### Note on Launch Configurations

AWS **deprecated creating new Launch Configurations on 2023-01-01**. If your account rejects `create-launch-configuration`, the script **automatically falls back to a Launch Template** (`calculator-lt`) and runs the ASG from it — same topology, modern API. This is transparent: both paths attach the group to the same ELB and health check.

## ASG/LC/ELB with Terraform

The `terraform/` directory replaces the CLI scripts from Tasks 2 and 4 with a single declarative, reusable deployment: **load balancer + Launch Template + Auto Scaling Group**, all in the default VPC. It uses a **Launch Template** instead of a Launch Configuration because AWS disabled creating new LCs on 2023-01-01 (same trade-off the CLI script already makes).

It runs in two modes:

| Mode | Trigger | Load balancer |
|---|---|---|
| Real AWS | `endpoint_url` empty (default) | **Classic ELB** (`aws_elb`) — exactly the homework resource |
| Local floci | `endpoint_url` set | **ALB + target group** (`aws_lb`) — floci's classic ELB can't be read back by the `aws_elb` provider |

```bash
cd homework/13-aws/terraform

terraform init        # downloads the AWS provider
terraform fmt         # normalize formatting
terraform validate    # syntax + consistency check
terraform plan        # preview changes against your account
terraform apply       # create SG, load balancer, Launch Template, ASG
```

By default the module auto-discovers the **most recent `calculator-microservice-*` AMI** in your account (i.e. the one Packer baked in Task 3). You can pin a specific image instead:

```bash
terraform apply -var ami_id=ami-<baked>            # or in terraform.tfvars
```

What gets created (real-AWS mode; locally the load balancer columns use the ALB names):

| Resource | Name | Notes |
|---|---|---|
| Security Group | `calculator-sg` | SSH 22 + app 8080 (same as Task 1) |
| Security Group | `calculator-elb-sg` | HTTP 80 for the load balancer |
| Classic ELB | `calculator-elb` | Listener `80 → 8080`, health check `HTTP:8080/calc/sum/1/2` |
| Launch Template | `calculator-lt` | `t2.micro`, baked AMI, app Security Group |
| Auto Scaling Group | `calculator-asg` | `min=1 max=3 desired=2`, ELB health check, attached to the load balancer |

To run it locally against floci instead of your AWS account:

```bash
docker compose -f local/docker-compose.yml up -d   # start floci (one terminal)
source local/aws-env.sh                            # fake credentials + endpoint

terraform apply -var endpoint_url=http://localhost:4566 \
                -var ami_id=ami-0abcdef1234567890   # floci's built-in image
```

After `apply`, the outputs give you the endpoint and a ready-to-run curl:

```bash
terraform output            # elb_dns_name, ami_id, asg_name, test_command ...
curl http://$(terraform output -raw elb_dns_name)/calc/sum/2/3
```

Try the scaling features (identical to Task 4):

```bash
aws autoscaling set-desired-capacity --auto-scaling-group-name calculator-asg \
  --desired-capacity 4
curl http://$(terraform output -raw elb_dns_name)/calc/sum/2/3
```

And tear everything down when done:

```bash
terraform destroy           # or: terraform destroy -auto-approve
```

> **Gotcha:** the CLI scripts and the Terraform module use the same resource names (`calculator-sg`, `calculator-elb`, …). Don't run both at the same time — pick one path (CLI **or** Terraform) per region, or Terraform `plan` will report drift.

---

## Finding the Ubuntu 22.04 AMI

Easiest way to resolve the current official image per region:

```bash
aws ec2 describe-images --owners 099720109477 --filters \
  "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'sort_by(Images,&CreationDate)[-1].[ImageId]' --output text
```

## Troubleshooting

- **ELB returns 503** (service unavailable): the health check (`HTTP:8080/calc/sum/1/2`) is failing. Confirm the instance serves `8080` directly and the Security Group allows `8080` from the ELB.
- **`02-launch-instance.sh` but the service isn't up**: `user-data.sh` runs only after boot; wait ~60s. If source wasn't uploaded, do the `scp` + build step shown above, or launch from the baked AMI instead.
- **Packer cannot find the plugin**: run `packer init calculator-ami.pkr.hcl` first.
- **Packer "source_ami_filter" finds nothing**: make sure you are in the region you expect (`-var aws_region=...`); the filter targets Canonical's official Ubuntu 22.04 images.
- **Clean extension**: when you are done, remove everything with `scripts/05-cleanup.sh`.
- **Costs**: everything is `t2.micro`/free-tier sized, but always run the cleanup when finished to avoid ongoing charges.
- **floci: scripts say VPC/subnet "None" or "does not exist"**: the emulator ignores the `isDefault` VPC filter; the scripts now fall back to the first VPC, but re-`source local/aws-env.sh` and make sure `AWS_ENDPOINT_URL` is set.
- **floci: stale resources after restart**: with `FLOCI_STORAGE_MODE=persistent` (the default compose file) old state survives; use `docker compose -f local/docker-compose.yml down -v` for a clean slate.
- **floci: `aws_elb` Terraform read fails ("too many results")**: expected — floci omits the source security-group that the `aws_elb` provider needs. Run Terraform with `-var endpoint_url=http://localhost:4566`, which switches the module to an ALB automatically.