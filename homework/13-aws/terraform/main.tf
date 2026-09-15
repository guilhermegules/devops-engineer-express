# Homework 13 - AWS (Task 5, Bonus) — all resources live in the default VPC.
# Prerequisite: bake the AMI first with Packer (packer/calculator-ami.pkr.hcl).
#
# Two modes:
#   * Real AWS  (endpoint_url = "")      -> Classic ELB, launched as in the homework.
#   * floci     (endpoint_url set)       -> Application Load Balancer, because floci's
#     classic ELB does not return the source-security-group that the aws_elb provider
#     requires, so aws_elb cannot be read back (known gap). Everything else is identical.

provider "aws" {
  region = var.aws_region

  # When endpoint_url is set (e.g. for the local floci emulator), redirect the
  # AWS calls to that endpoint instead of real AWS, and skip the real-AWS
  # credential / account-id validations (floci accepts any non-empty creds).
  skip_credentials_validation = var.endpoint_url != "" ? true : null
  skip_requesting_account_id  = var.endpoint_url != "" ? true : null
  skip_metadata_api_check     = var.endpoint_url != "" ? true : null

  dynamic "endpoints" {
    for_each = var.endpoint_url != "" ? [var.endpoint_url] : []
    content {
      ec2                    = endpoints.value
      elb                    = endpoints.value
      elasticloadbalancingv2 = endpoints.value
      autoscaling            = endpoints.value
      sts                    = endpoints.value
      iam                    = endpoints.value
    }
  }

  default_tags {
    tags = {
      Homework    = "13-aws"
      ManagedBy   = "terraform"
      Application = "calculator-microservice"
    }
  }
}

locals {
  local_mode = var.endpoint_url != ""
}

# --- Data sources: default VPC + its subnets + the Packer-baked AMI ----------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Auto-discover the most recent AMI baked by Packer unless var.ami_id is set.
# When running against floci (var.endpoint_url set) skip the lookup and let the
# user pass any id, e.g. floci's built-in ami-0abcdef1234567890.
data "aws_ami" "calculator" {
  count = var.ami_id == "" && var.endpoint_url == "" ? 1 : 0

  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["${var.ami_name_prefix}-*"]
  }
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : one(data.aws_ami.calculator[*].id)
}

# --- Security groups -----------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "calculator-sg"
  description = "Allow SSH and calculator microservice traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "elb" {
  name        = "calculator-elb-sg"
  description = "ELB for calculator microservice"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Load balancer -------------------------------------------------------------

# Classic ELB (80 -> 8080) — the resource from the homework, used on real AWS.
resource "aws_elb" "calculator" {
  count = local.local_mode ? 0 : 1

  name            = "calculator-elb"
  subnets         = data.aws_subnets.default.ids
  security_groups = [aws_security_group.elb.id]

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    target              = "HTTP:8080/calc/sum/1/2"
    interval            = 30
  }
}

# ALB + target group — used instead of the Classic ELB when running against floci.
resource "aws_lb" "calculator" {
  count = local.local_mode ? 1 : 0

  name               = "calculator-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "calculator" {
  count = local.local_mode ? 1 : 0

  name     = "calculator-alb-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    path                = "/calc/sum/1/2"
    protocol            = "HTTP"
    port                = "8080"
    interval            = 30
  }
}

resource "aws_lb_listener" "calculator" {
  count = local.local_mode ? 1 : 0

  load_balancer_arn = aws_lb.calculator[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.calculator[0].arn
  }
}

# --- Launch template + Auto Scaling Group --------------------------------------
# Launch Configurations were deprecated by AWS on 2023-01-01, so we use the
# modern Launch Template (same role, same naming) like scripts/04-create-asg.sh.

resource "aws_launch_template" "calculator" {
  name          = "calculator-lt"
  image_id      = local.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  vpc_security_group_ids = [aws_security_group.app.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "calculator-instance"
    }
  }
}

resource "aws_autoscaling_group" "calculator" {
  name                      = "calculator-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = data.aws_subnets.default.ids
  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period

  load_balancers    = local.local_mode ? [] : [aws_elb.calculator[0].name]
  target_group_arns = local.local_mode ? [aws_lb_target_group.calculator[0].arn] : []

  launch_template {
    id      = aws_launch_template.calculator.id
    version = "$Latest"
  }
}