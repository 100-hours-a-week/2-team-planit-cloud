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
  description = "VPC IPv4 CIDR. 운영(prod)은 10.0.0.0/16, 테스트/IaC 검증용은 10.1.0.0/16 등으로 분리 권장."
  type        = string
  default     = "10.1.0.0/16"
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
  description = "EC2 SSM Role 인라인 정책(JSON 문자열). 기본값: ECR 로그인·풀 정책"
  type        = string
  default = <<-EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRLogin",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "ECRPull",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "arn:aws:ecr:ap-northeast-2:713881824287:repository/planit-was"
    }
  ]
}
EOT
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

variable "mongo_instance_type" {
  description = "MongoDB EC2 인스턴스 타입"
  type        = string
  default     = "t4g.small"
}

variable "cloudfront_s3_origin_path" {
  description = "CloudFront S3 origin path"
  type        = string
  default     = "/dist"
}

variable "cloudfront_aliases" {
  description = "CloudFront Alternate Domain Names(CNAME) 목록"
  type        = list(string)
  default     = ["planit-ai.store"]
}

variable "cloudfront_distribution_id" {
  description = "기존 CloudFront 배포 ID (도메인 dijh9mhj7vomy.cloudfront.net)"
  type        = string
  default     = "EFRIGL57680PY"
}

variable "cloudfront_acm_certificate_arn" {
  description = "CloudFront용 ACM 인증서 ARN(us-east-1). 기존 배포 참조 시 미사용"
  type        = string
  default     = null
}

variable "cloudfront_minimum_protocol_version" {
  description = "CloudFront 최소 TLS 버전"
  type        = string
  default     = "TLSv1.2_2021"
}

variable "cloudfront_price_class" {
  description = "CloudFront 가격 등급"
  type        = string
  default     = "PriceClass_All"
}

variable "cloudfront_default_root_object" {
  description = "CloudFront 기본 루트 객체"
  type        = string
  default     = "index.html"
}

variable "cloudfront_http_version" {
  description = "CloudFront HTTP 버전"
  type        = string
  default     = "http2"
}

# 이미지 업로드 S3 오리진 (항상 생성)
variable "cloudfront_s3_image_origin_domain_name" {
  description = "이미지 업로드 S3 버킷 Regional Domain Name (예: planit-s3-bucket.s3.ap-northeast-2.amazonaws.com). null이면 기본값 사용."
  type        = string
  default     = "planit-s3-bucket.s3.ap-northeast-2.amazonaws.com"
}

variable "cloudfront_image_path_patterns" {
  description = "이미지 S3 오리진으로 라우팅할 path pattern 목록 (예: [\"/profile/*\", \"/post/*\"])"
  type        = list(string)
  default     = ["/profile/*", "/post/*"]
}

variable "image_bucket_name" {
  description = "이미지 업로드 S3 버킷 이름 (정책·CORS 관리 대상)"
  type        = string
  default     = "planit-s3-bucket"
}

variable "image_bucket_cors_origins" {
  description = "이미지 S3 버킷 CORS AllowedOrigins"
  type        = list(string)
  default     = ["http://localhost:5173", "http://localhost:3000", "https://planit-ai.store", "https://www.planit-ai.store", "https://d1e7kkp6huat07.cloudfront.net"]
}

variable "route53_zone_name" {
  description = "Route53 Public Hosted Zone 이름"
  type        = string
  default     = "planit-ai.store."
}

variable "route53_record_name" {
  description = "Route53 레코드 이름"
  type        = string
  default     = "planit-ai.store"
}

variable "route53_set_identifier" {
  description = "가중치 기반 라우팅 set_identifier"
  type        = string
  default     = "v2 fe cloudfront"
}

variable "route53_weight" {
  description = "가중치 기반 라우팅 weight"
  type        = number
  default     = 0
}

variable "route53_evaluate_target_health" {
  description = "Alias 대상 헬스체크 평가 여부"
  type        = bool
  default     = false
}

variable "enable_route53_record" {
  description = "Route53 apex A 레코드 생성 여부"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Compute 모듈 (WAS ASG)
# ------------------------------------------------------------------------------

variable "was_ami_id" {
  description = "WAS 인스턴스용 AMI ID"
  type        = string
  default     = "ami-015c6c86e4847c159"
}

variable "was_instance_type" {
  description = "WAS 인스턴스 타입"
  type        = string
  default     = "t4g.small"
}

variable "was_key_name" {
  description = "WAS 인스턴스 SSH 키 페어 이름"
  type        = string
  default     = "planit-keypair"
}

variable "was_asg_min_size" {
  description = "WAS ASG 최소 인스턴스 수"
  type        = number
  default     = 2
}

variable "was_asg_desired_capacity" {
  description = "WAS ASG 희망 인스턴스 수"
  type        = number
  default     = 4
}

variable "was_asg_max_size" {
  description = "WAS ASG 최대 인스턴스 수"
  type        = number
  default     = 4
}

variable "was_health_check_type" {
  description = "WAS ASG 헬스체크 타입"
  type        = string
  default     = "ELB"
}

variable "was_health_check_grace_period" {
  description = "WAS ASG 헬스체크 유예시간(초)"
  type        = number
  default     = 300
}

variable "was_user_data_base64" {
  description = "WAS Launch Template user_data(base64). 없으면 null"
  type        = string
  default     = null
}

variable "was_iam_instance_profile_name" {
  description = "WAS 인스턴스에 연결할 IAM Instance Profile 이름. 없으면 null"
  type        = string
  default     = "EC2-SSM-Role"
}

# ------------------------------------------------------------------------------
# Compute 모듈 (AI ASG)
# ------------------------------------------------------------------------------

variable "ai_ami_id" {
  description = "AI 인스턴스용 AMI ID"
  type        = string
  default     = "ami-015c6c86e4847c159"
}

variable "ai_instance_type" {
  description = "AI 인스턴스 타입"
  type        = string
  default     = "t4g.small"
}

variable "ai_key_name" {
  description = "AI 인스턴스 SSH 키 페어 이름"
  type        = string
  default     = "planit-keypair"
}

variable "ai_asg_min_size" {
  description = "AI ASG 최소 인스턴스 수"
  type        = number
  default     = 1
}

variable "ai_asg_desired_capacity" {
  description = "AI ASG 희망 인스턴스 수"
  type        = number
  default     = 1
}

variable "ai_asg_max_size" {
  description = "AI ASG 최대 인스턴스 수"
  type        = number
  default     = 2
}

variable "ai_health_check_type" {
  description = "AI ASG 헬스체크 타입"
  type        = string
  default     = "ELB"
}

variable "ai_health_check_grace_period" {
  description = "AI ASG 헬스체크 유예시간(초)"
  type        = number
  default     = 300
}

variable "ai_user_data_base64" {
  description = "AI Launch Template user_data(base64). 없으면 null"
  type        = string
  default     = null
}

variable "ai_iam_instance_profile_name" {
  description = "AI 인스턴스에 연결할 IAM Instance Profile 이름. 없으면 null"
  type        = string
  default     = "EC2-SSM-Role"
}

# ------------------------------------------------------------------------------
# Compute 모듈 (Chat EC2)
# ------------------------------------------------------------------------------

variable "chat_ami_id" {
  description = "Chat 인스턴스용 AMI ID"
  type        = string
  default     = "ami-015c6c86e4847c159"
}

variable "chat_instance_type" {
  description = "Chat 인스턴스 타입"
  type        = string
  default     = "t4g.small"
}

variable "chat_key_name" {
  description = "Chat 인스턴스 SSH 키 페어 이름"
  type        = string
  default     = "planit-keypair"
}

variable "chat_iam_instance_profile_name" {
  description = "Chat 인스턴스에 연결할 IAM Instance Profile 이름. 없으면 null"
  type        = string
  default     = "EC2-SSM-Role"
}

variable "chat_user_data_base64" {
  description = "Chat 인스턴스 user_data(base64). 없으면 null"
  type        = string
  default     = null
}

variable "chat_root_volume_size_gb" {
  description = "Chat 인스턴스 루트 볼륨 크기(GB)"
  type        = number
  default     = 30
}

variable "chat_root_volume_type" {
  description = "Chat 인스턴스 루트 볼륨 타입"
  type        = string
  default     = "gp3"
}

variable "chat_root_volume_encrypted" {
  description = "Chat 인스턴스 루트 볼륨 암호화 여부"
  type        = bool
  default     = true
}
