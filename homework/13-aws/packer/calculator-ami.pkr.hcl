packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ami_name" {
  type    = string
  default = "calculator-microservice"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

source "amazon-ebs" "calculator" {
  ami_name        = "${var.ami_name}-{{timestamp}}"
  instance_type   = var.instance_type
  region          = var.aws_region
  ssh_username    = "ubuntu"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"]
    most_recent = true
  }

  tags = {
    Name        = var.ami_name
    Application = "calculator-microservice"
    Homework    = "13-aws"
  }
}

build {
  sources = ["source.amazon-ebs.calculator"]

  provisioner "file" {
    source      = "${path.root}/../../06-go"
    destination = "/tmp/calculator"
  }

  provisioner "shell" {
    script = "${path.root}/provision-calculator.sh"
  }
}
