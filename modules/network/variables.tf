# ------------------------------------------------------------------------------
# 공통
# ------------------------------------------------------------------------------

variable "environment" {
  description = "환경 이름 (예: dev, prod). 리소스 이름/태그에 사용됩니다."
  type        = string
  default     = "prod"
}

variable "project" {
  description = "프로젝트 이름. 리소스 이름/태그에 사용됩니다."
  type        = string
  default     = "planit"
}

variable "region" {
  description = "AWS 리전 (예: ap-northeast-2)"
  type        = string
  default     = "ap-northeast-2"
}

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

# ------------------------------------------------------------------------------
# NAT Instance (Private 서브넷 아웃바운드용)
# ------------------------------------------------------------------------------

variable "nat_instance_type" {
  description = "NAT Instance 인스턴스 타입"
  type        = string
  default     = "t4g.micro"
}

variable "nat_instance_ami_id" {
  description = "NAT Instance용 AMI ID"
  type        = string
  default     = "ami-04f06fb5ae9dcc778"
}

variable "nat_instance_key_name" {
  description = "NAT Instance SSH용 키 페어 이름"
  type        = string
  default     = "planit-keypair"
}

variable "enable_nat_instance" {
  description = "NAT Instance 생성 여부. false면 Private 서브넷에서 인터넷 아웃바운드 불가"
  type        = bool
  default     = true
}
