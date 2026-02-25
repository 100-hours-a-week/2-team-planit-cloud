# ------------------------------------------------------------------------------
# Network 모듈 출력 재노출
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

output "security_group_ids" {
  description = "Security 모듈 보안그룹 ID 매핑"
  value       = module.security.security_group_ids
}

output "iam_role_names" {
  description = "Security 모듈 IAM Role 이름 매핑"
  value       = module.security.iam_role_names
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
