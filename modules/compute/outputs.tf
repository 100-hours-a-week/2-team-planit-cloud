output "was_launch_template_id" {
  description = "WAS Launch Template ID"
  value       = aws_launch_template.was.id
}

output "was_launch_template_latest_version" {
  description = "WAS Launch Template 최신 버전"
  value       = aws_launch_template.was.latest_version
}

output "was_asg_name" {
  description = "WAS Auto Scaling Group 이름"
  value       = aws_autoscaling_group.was.name
}

output "was_asg_arn" {
  description = "WAS Auto Scaling Group ARN"
  value       = aws_autoscaling_group.was.arn
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.app.arn
}

output "alb_dns_name" {
  description = "ALB DNS 이름"
  value       = aws_lb.app.dns_name
}

output "alb_zone_id" {
  description = "ALB Hosted Zone ID"
  value       = aws_lb.app.zone_id
}

output "was_target_group_arn" {
  description = "WAS Target Group ARN"
  value       = aws_lb_target_group.was.arn
}

output "ai_target_group_arn" {
  description = "AI Target Group ARN"
  value       = aws_lb_target_group.ai.arn
}

output "chat_target_group_arn" {
  description = "Chat Target Group ARN"
  value       = aws_lb_target_group.chat.arn
}

output "ai_launch_template_id" {
  description = "AI Launch Template ID"
  value       = aws_launch_template.ai.id
}

output "ai_launch_template_latest_version" {
  description = "AI Launch Template 최신 버전"
  value       = aws_launch_template.ai.latest_version
}

output "ai_asg_name" {
  description = "AI Auto Scaling Group 이름"
  value       = aws_autoscaling_group.ai.name
}

output "ai_asg_arn" {
  description = "AI Auto Scaling Group ARN"
  value       = aws_autoscaling_group.ai.arn
}

output "chat_instance_id" {
  description = "Chat EC2 Instance ID"
  value       = aws_instance.chat.id
}

output "chat_private_ip" {
  description = "Chat EC2 Private IP"
  value       = aws_instance.chat.private_ip
}

output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID"
  value       = data.aws_cloudfront_distribution.app.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront Distribution ARN (S3 버킷 정책 Condition 등에서 사용)"
  value       = data.aws_cloudfront_distribution.app.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront Domain Name"
  value       = data.aws_cloudfront_distribution.app.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront Hosted Zone ID"
  value       = data.aws_cloudfront_distribution.app.hosted_zone_id
}

