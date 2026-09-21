output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.ha-infra.dns_name
}

output "alb_url" {
  description = "HTTP URL to access the deployed web application"
  value       = "http://${aws_lb.ha-infra.dns_name}"
}

output "vpc_id" {
  description = "ID of the VPC created"
  value       = module.vpc.vpc_id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.ha-infra.name
}

output "target_group_arn" {
  description = "ARN of the ALB Target Group"
  value       = aws_lb_target_group.ha-infra.arn
}
