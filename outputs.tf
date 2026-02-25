# ------------------------------------------------------------------------------
# Network 모듈
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public 서브넷 ID 목록"
  value       = module.network.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "Private Application 서브넷 ID 목록"
  value       = module.network.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "Private Database 서브넷 ID 목록"
  value       = module.network.private_db_subnet_ids
}

output "availability_zones" {
  description = "사용 가용 영역"
  value       = module.network.availability_zones
}

output "nat_instance_ids" {
  description = "NAT Instance ID 목록"
  value       = module.network.nat_instance_ids
}

# ------------------------------------------------------------------------------
# Security 모듈
# ------------------------------------------------------------------------------

output "security_group_ids" {
  description = "Security 모듈 보안그룹 ID 매핑"
  value       = module.security.security_group_ids
}

output "iam_role_names" {
  description = "Security 모듈 IAM Role 이름 매핑"
  value       = module.security.iam_role_names
}

output "cloudfront_oai_id" {
  description = "CloudFront OAI ID"
  value       = aws_cloudfront_origin_access_identity.this.id
}

output "cloudfront_oai_iam_arn" {
  description = "CloudFront OAI IAM ARN"
  value       = aws_cloudfront_origin_access_identity.this.iam_arn
}

# ------------------------------------------------------------------------------
# Storage 모듈
# ------------------------------------------------------------------------------

output "db_primary_instance_id" {
  description = "MySQL Primary EC2 ID"
  value       = module.storage.db_primary_instance_id
}

output "db_primary_private_ip" {
  description = "MySQL Primary Private IP"
  value       = module.storage.db_primary_private_ip
}

output "db_replica_instance_ids" {
  description = "MySQL Replica EC2 ID 목록"
  value       = module.storage.db_replica_instance_ids
}

output "fe_bucket_name" {
  description = "FE/업로드 S3 버킷 이름"
  value       = module.storage.fe_bucket_name
}

output "backup_bucket_name" {
  description = "DB 백업 S3 버킷 이름"
  value       = module.storage.backup_bucket_name
}

# ------------------------------------------------------------------------------
# Compute 모듈
# ------------------------------------------------------------------------------

output "was_launch_template_id" {
  description = "WAS Launch Template ID"
  value       = module.compute.was_launch_template_id
}

output "was_asg_name" {
  description = "WAS Auto Scaling Group 이름"
  value       = module.compute.was_asg_name
}

output "was_asg_arn" {
  description = "WAS Auto Scaling Group ARN"
  value       = module.compute.was_asg_arn
}

output "ai_launch_template_id" {
  description = "AI Launch Template ID"
  value       = module.compute.ai_launch_template_id
}

output "ai_asg_name" {
  description = "AI Auto Scaling Group 이름"
  value       = module.compute.ai_asg_name
}

output "ai_asg_arn" {
  description = "AI Auto Scaling Group ARN"
  value       = module.compute.ai_asg_arn
}

output "chat_instance_id" {
  description = "Chat EC2 Instance ID"
  value       = module.compute.chat_instance_id
}

output "chat_private_ip" {
  description = "Chat EC2 Private IP"
  value       = module.compute.chat_private_ip
}

output "alb_dns_name" {
  description = "ALB DNS 이름"
  value       = module.compute.alb_dns_name
}

output "alb_zone_id" {
  description = "ALB Hosted Zone ID"
  value       = module.compute.alb_zone_id
}

output "was_target_group_arn" {
  description = "WAS Target Group ARN"
  value       = module.compute.was_target_group_arn
}

output "ai_target_group_arn" {
  description = "AI Target Group ARN"
  value       = module.compute.ai_target_group_arn
}

output "chat_target_group_arn" {
  description = "Chat Target Group ARN"
  value       = module.compute.chat_target_group_arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID"
  value       = module.compute.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront Domain Name"
  value       = module.compute.cloudfront_domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront Hosted Zone ID"
  value       = module.compute.cloudfront_hosted_zone_id
}

output "route53_zone_id" {
  description = "Route53 Public Hosted Zone ID"
  value       = module.compute.route53_zone_id
}

output "route53_apex_a_fqdn" {
  description = "Route53 apex A 레코드 FQDN"
  value       = module.compute.route53_apex_a_fqdn
}
