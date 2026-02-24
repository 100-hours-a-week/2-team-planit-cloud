# ------------------------------------------------------------------------------
# VPC & IGW
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR 블록"
  value       = aws_vpc.main.cidr_block
}

output "igw_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

# ------------------------------------------------------------------------------
# 서브넷 ID (다른 모듈에서 참조)
# ------------------------------------------------------------------------------

output "public_subnet_ids" {
  description = "Public 서브넷 ID 목록 (ALB, NAT 배치용)"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "Private Application 서브넷 ID 목록 (WAS, Queue 배치용)"
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "Private Database 서브넷 ID 목록 (RDS, MongoDB 등 배치용)"
  value       = aws_subnet.private_db[*].id
}

# ------------------------------------------------------------------------------
# 가용 영역
# ------------------------------------------------------------------------------

output "availability_zones" {
  description = "사용 중인 가용 영역 목록"
  value       = local.azs
}

# ------------------------------------------------------------------------------
# NAT Instance (선택)
# ------------------------------------------------------------------------------

output "nat_instance_id" {
  description = "NAT Instance ID (enable_nat_instance=true일 때만)"
  value       = var.enable_nat_instance ? aws_instance.nat[0].id : null
}

output "nat_instance_private_ip" {
  description = "NAT Instance Private IP"
  value       = var.enable_nat_instance ? aws_instance.nat[0].private_ip : null
}
