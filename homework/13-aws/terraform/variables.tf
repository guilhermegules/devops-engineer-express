variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "Baked calculator AMI id. When empty, the most recent 'calculator-microservice-*' AMI in your account is auto-discovered."
  type        = string
  default     = ""
}

variable "ami_name_prefix" {
  description = "Name prefix of the Packer-baked AMI used for auto-discovery"
  type        = string
  default     = "calculator-microservice"
}

variable "instance_type" {
  description = "EC2 instance type for the Auto Scaling Group"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH access"
  type        = string
  default     = ""
}

variable "min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 2
}

variable "health_check_grace_period" {
  description = "Seconds the ASG waits before starting ELB health checks"
  type        = number
  default     = 300
}

variable "endpoint_url" {
  description = "Custom AWS-compatible endpoint, e.g. http://localhost:4566 to run against floci with no AWS account. Leave empty for real AWS."
  type        = string
  default     = ""
}