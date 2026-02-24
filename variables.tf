# ------------------------------------------------------------------------------
# 루트 변수 (모듈에 전달)
# ------------------------------------------------------------------------------

variable "environment" {
  description = "환경 (dev, prod)"
  type        = string
  default     = "prod"
}

variable "project" {
  description = "프로젝트 이름"
  type        = string
  default     = "planit"
}

variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_instance" {
  description = "NAT Instance 생성 여부"
  type        = bool
  default     = true
}

variable "nat_instance_type" {
  description = "NAT Instance 인스턴스 타입"
  type        = string
  default     = "t4g.micro"
}

variable "nat_instance_ami_id" {
  description = "NAT Instance AMI ID"
  type        = string
  default     = "ami-04f06fb5ae9dcc778"
}

variable "nat_instance_key_name" {
  description = "NAT Instance SSH 키 페어 이름"
  type        = string
  default     = "planit-keypair"
}
