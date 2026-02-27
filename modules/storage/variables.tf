# ------------------------------------------------------------------------------
# 공통 (root에서 전달)
# ------------------------------------------------------------------------------

variable "environment" {
  description = "환경 (root variables.tf와 동일)"
  type        = string
}

variable "project" {
  description = "프로젝트 이름 (root variables.tf와 동일)"
  type        = string
}

# ------------------------------------------------------------------------------
# DB EC2 (MySQL Primary / Read Replica / Arbiter)
# ------------------------------------------------------------------------------

variable "private_db_subnet_ids" {
  description = "Private DB 서브넷 ID 목록 [subnet_a, subnet_b]"
  type        = list(string)
}

variable "application_sg_id" {
  description = "DB EC2 보안 그룹 ID (modules/security의 security_group_ids.db 전달)"
  type        = string
}

variable "db_ami_id" {
  description = "DB EC2 AMI ID"
  type        = string
}

variable "db_key_name" {
  description = "DB EC2 SSH 키 페어 이름"
  type        = string
}

variable "db_primary_instance_type" {
  description = "MySQL Primary 인스턴스 타입"
  type        = string
  default     = "t4g.small"
}

variable "db_replica_instance_type" {
  description = "MySQL Read Replica 인스턴스 타입"
  type        = string
  default     = "t4g.small"
}

variable "db_arbiter_instance_type" {
  description = "Arbiter 인스턴스 타입"
  type        = string
  default     = "t4g.nano"
}

# ------------------------------------------------------------------------------
# MongoDB EC2
# ------------------------------------------------------------------------------

variable "mongo_ami_id" {
  description = "MongoDB EC2 AMI ID"
  type        = string
}

variable "mongo_instance_type" {
  description = "MongoDB 인스턴스 타입"
  type        = string
  default     = "t4g.small"
}

# ------------------------------------------------------------------------------
# EBS
# ------------------------------------------------------------------------------

variable "db_root_volume_size_gb" {
  description = "DB EC2 Root(OS) 볼륨 크기(GB)"
  type        = number
  default     = 10
}

variable "db_data_volume_size_gb" {
  description = "DB EC2 데이터 전용 EBS 볼륨 크기(GB)"
  type        = number
  default     = 20
}

variable "db_volume_type" {
  description = "DB EBS 볼륨 타입"
  type        = string
  default     = "gp3"
}

# ------------------------------------------------------------------------------
# S3
# ------------------------------------------------------------------------------

variable "fe_bucket_name" {
  description = "FE 정적 파일 업로드용 S3 버킷 이름"
  type        = string
  default     = "planit-prod-fe-s3-bucket"
}

variable "backup_bucket_name" {
  description = "DB 백업용 S3 버킷 이름"
  type        = string
  default     = "planit-prod-db-backup-s3"
}
