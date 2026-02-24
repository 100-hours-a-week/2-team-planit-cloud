variable "vpc_id" {
  description = "Security Group을 생성할 VPC ID"
  type        = string
}

variable "project" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 이름"
  type        = string
}

variable "ec2_assume_role_service" {
  description = "EC2 Role의 AssumeRole 서비스 주체"
  type        = string
  default     = "ec2.amazonaws.com"
}

variable "ec2_ssm_managed_policy_arns" {
  description = "EC2 SSM Role에 부착할 관리형 정책 ARN 목록"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

variable "ec2_ssm_inline_policy_json" {
  description = "EC2 SSM Role 인라인 정책(JSON 문자열). 없으면 null"
  type        = string
  default     = null
}

variable "ec2_s3_managed_policy_arns" {
  description = "EC2 S3 Role에 부착할 관리형 정책 ARN 목록"
  type        = list(string)
  default     = []
}

variable "ec2_s3_inline_policy_json" {
  description = "EC2 S3 Role 인라인 정책(JSON 문자열). 없으면 null"
  type        = string
  default     = null
}
