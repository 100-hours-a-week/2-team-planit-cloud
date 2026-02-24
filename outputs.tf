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
