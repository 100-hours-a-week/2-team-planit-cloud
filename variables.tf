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

variable "ec2_assume_role_service" {
  description = "EC2 Role의 AssumeRole 서비스 주체"
  type        = string
  default     = "ec2.amazonaws.com"
}

variable "ec2_ssm_managed_policy_arns" {
  description = "EC2 SSM Role에 부착할 관리형 정책 ARN 목록"
  type        = list(string)
  default = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ]
}

variable "ec2_ssm_inline_policy_json" {
  description = "EC2 SSM Role 인라인 정책(JSON 문자열). 없으면 null"
  type        = string
  default = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRLogin"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = "arn:aws:ecr:ap-northeast-2:713881824287:repository/planit-was"
      },
    ]
  })
}

variable "ec2_s3_managed_policy_arns" {
  description = "EC2 S3 Role에 부착할 관리형 정책 ARN 목록"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
}

variable "ec2_s3_inline_policy_json" {
  description = "EC2 S3 Role 인라인 정책(JSON 문자열). 없으면 null"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Storage 모듈
# ------------------------------------------------------------------------------

variable "db_ami_id" {
  description = "DB EC2 AMI ID (NAT와 동일 권장)"
  type        = string
  default     = "ami-04f06fb5ae9dcc778"
}

variable "db_key_name" {
  description = "DB EC2 SSH 키 페어 이름"
  type        = string
  default     = "planit-keypair"
}

variable "db_root_volume_size_gb" {
  description = "DB EC2 Root 볼륨 크기(GB)"
  type        = number
  default     = 10
}

variable "db_data_volume_size_gb" {
  description = "DB EC2 데이터 EBS 볼륨 크기(GB)"
  type        = number
  default     = 20
}

variable "cloudfront_oai_iam_arn" {
  description = "CloudFront OAI IAM ARN (FE 버킷 GetObject 허용, 필수)"
  type        = string
}
