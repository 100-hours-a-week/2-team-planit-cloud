# ------------------------------------------------------------------------------
# DB EC2
# ------------------------------------------------------------------------------

output "db_primary_instance_id" {
  description = "MySQL Primary EC2 Instance ID"
  value       = aws_instance.db_primary[0].id
}

output "db_primary_private_ip" {
  description = "MySQL Primary Private IP"
  value       = aws_instance.db_primary[0].private_ip
}

output "db_replica_instance_ids" {
  description = "MySQL Read Replica EC2 Instance ID 목록"
  value       = aws_instance.db_replica[*].id
}

output "db_replica_private_ips" {
  description = "MySQL Read Replica Private IP 목록"
  value       = aws_instance.db_replica[*].private_ip
}

output "db_arbiter_instance_id" {
  description = "MySQL Arbiter EC2 Instance ID"
  value       = aws_instance.db_arbiter[0].id
}

output "db_arbiter_private_ip" {
  description = "MySQL Arbiter Private IP"
  value       = aws_instance.db_arbiter[0].private_ip
}

output "db_sg_id" {
  description = "DB EC2에 적용된 보안 그룹 ID (modules/security의 db SG)"
  value       = var.application_sg_id
}

output "mongo_instance_id" {
  description = "MongoDB EC2 Instance ID"
  value       = aws_instance.mongo[0].id
}

output "mongo_private_ip" {
  description = "MongoDB EC2 Private IP"
  value       = aws_instance.mongo[0].private_ip
}

# ------------------------------------------------------------------------------
# S3
# ------------------------------------------------------------------------------

output "fe_bucket_name" {
  description = "FE/업로드용 S3 버킷 이름"
  value       = aws_s3_bucket.fe.id
}

output "fe_bucket_arn" {
  description = "FE/업로드용 S3 버킷 ARN"
  value       = aws_s3_bucket.fe.arn
}

output "fe_bucket_regional_domain_name" {
  description = "FE/업로드용 S3 버킷 Regional Domain Name"
  value       = aws_s3_bucket.fe.bucket_regional_domain_name
}

output "backup_bucket_name" {
  description = "DB 백업용 S3 버킷 이름"
  value       = aws_s3_bucket.backup.id
}

output "backup_bucket_arn" {
  description = "DB 백업용 S3 버킷 ARN"
  value       = aws_s3_bucket.backup.arn
}
