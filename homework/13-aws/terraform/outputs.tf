output "elb_dns_name" {
  description = "DNS name of the load balancer in front of the microservice"
  value       = local.local_mode ? aws_lb.calculator[0].dns_name : aws_elb.calculator[0].dns_name
}

output "elb_name" {
  description = "Name of the load balancer"
  value       = local.local_mode ? aws_lb.calculator[0].name : aws_elb.calculator[0].name
}

output "ami_id" {
  description = "AMI id used by the Auto Scaling Group launch template"
  value       = local.ami_id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.calculator.name
}

output "app_security_group_id" {
  description = "Security Group attached to the instances"
  value       = aws_security_group.app.id
}

output "test_command" {
  description = "How to verify the deployment through the load balancer"
  value       = "curl http://${local.local_mode ? aws_lb.calculator[0].dns_name : aws_elb.calculator[0].dns_name}/calc/sum/2/3"
}