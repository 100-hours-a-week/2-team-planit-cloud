# ------------------------------------------------------------------------------
# 공통 (root에서 전달)
# ------------------------------------------------------------------------------

variable "environment" {
  description = "환경 이름"
  type        = string
}

variable "project" {
  description = "프로젝트 이름"
  type        = string
}

# ------------------------------------------------------------------------------
# ALB
# ------------------------------------------------------------------------------

variable "vpc_id" {
  description = "ALB/TG가 생성될 VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "ALB가 배치될 Public 서브넷 ID 목록"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB에 적용할 보안그룹 ID"
  type        = string
}

variable "alb_internal" {
  description = "ALB internal 여부"
  type        = bool
  default     = false
}

variable "alb_idle_timeout" {
  description = "ALB idle timeout(초)"
  type        = number
  default     = 60
}

variable "alb_enable_deletion_protection" {
  description = "ALB 삭제 보호 활성화 여부"
  type        = bool
  default     = false
}

variable "was_target_group_port" {
  description = "WAS Target Group 포트"
  type        = number
  default     = 8080
}

variable "ai_target_group_port" {
  description = "AI Target Group 포트"
  type        = number
  default     = 8000
}

variable "chat_target_group_port" {
  description = "Chat Target Group 포트"
  type        = number
  default     = 8081
}

variable "was_target_group_health_check_path" {
  description = "WAS Target Group 헬스체크 경로"
  type        = string
  default     = "/api/health"
}

variable "ai_target_group_health_check_path" {
  description = "AI Target Group 헬스체크 경로"
  type        = string
  default     = "/health"
}

variable "chat_target_group_health_check_path" {
  description = "Chat Target Group 헬스체크 경로"
  type        = string
  default     = "/api/health"
}

variable "target_group_health_check_matcher" {
  description = "Target Group 헬스체크 응답코드 matcher"
  type        = string
  default     = "200-399"
}

variable "chat_listener_path_patterns" {
  description = "HTTP 80 리스너에서 Chat TG로 라우팅할 path pattern 목록"
  type        = list(string)
  default     = ["/api/ws/*"]
}

variable "was_listener_path_patterns" {
  description = "HTTP 80 리스너에서 WAS TG로 라우팅할 path pattern 목록"
  type        = list(string)
  default     = ["/api/*"]
}

variable "ai_listener_path_patterns" {
  description = "HTTP 80 리스너에서 AI TG로 라우팅할 path pattern 목록"
  type        = list(string)
  default     = ["/ai/*"]
}

variable "chat_listener_rule_priority" {
  description = "Chat 리스너 규칙 우선순위"
  type        = number
  default     = 1
}

variable "was_listener_rule_priority" {
  description = "WAS 리스너 규칙 우선순위"
  type        = number
  default     = 2
}

variable "ai_listener_rule_priority" {
  description = "AI 리스너 규칙 우선순위"
  type        = number
  default     = 3
}

# ------------------------------------------------------------------------------
# CloudFront
# ------------------------------------------------------------------------------

variable "cloudfront_s3_origin_domain_name" {
  description = "CloudFront S3 Origin Domain Name (기존 배포 참조 시 미사용)"
  type        = string
  default     = null
}

variable "cloudfront_s3_origin_path" {
  description = "CloudFront S3 Origin Path"
  type        = string
  default     = "/dist"
}

variable "cloudfront_distribution_id" {
  description = "기존 CloudFront 배포 ID (도메인 dijh9mhj7vomy.cloudfront.net)"
  type        = string
}

variable "cloudfront_oai_id" {
  description = "CloudFront Origin Access Identity ID (기존 배포 참조 시 미사용)"
  type        = string
  default     = null
}

variable "cloudfront_aliases" {
  description = "CloudFront Alternate Domain Names(CNAME) 목록"
  type        = list(string)
  default     = []
}

variable "cloudfront_acm_certificate_arn" {
  description = "CloudFront용 ACM 인증서 ARN(us-east-1). 없으면 기본 인증서 사용"
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

# 이미지 업로드용 S3 오리진
variable "cloudfront_s3_image_origin_domain_name" {
  description = "이미지 업로드 S3 버킷 Regional Domain Name (예: planit-s3-bucket.s3.ap-northeast-2.amazonaws.com). 해당 버킷 정책에 동일 OAI GetObject 허용 필요."
  type        = string
  default     = "planit-s3-bucket.s3.ap-northeast-2.amazonaws.com"
}

variable "cloudfront_image_path_patterns" {
  description = "이미지 S3 오리진으로 라우팅할 path pattern 목록 (우선순위 순: /profile/*, /post/*)"
  type        = list(string)
  default     = ["/profile/*", "/post/*"]
}

# ------------------------------------------------------------------------------
# Route53
# ------------------------------------------------------------------------------

variable "route53_zone_name" {
  description = "Route53 Public Hosted Zone 이름"
  type        = string
  default     = "planit-ai.store."
}

variable "route53_record_name" {
  description = "Route53 레코드 이름(apex는 도메인과 동일)"
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
  default     = 255
}

variable "route53_evaluate_target_health" {
  description = "Alias 대상 헬스체크 평가 여부"
  type        = bool
  default     = false
}

variable "enable_route53_record" {
  description = "Route53 apex A 레코드 생성 여부. false면 도메인 연결 없이 CloudFront 기본 URL만 사용"
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# WAS ASG
# ------------------------------------------------------------------------------

variable "private_app_subnet_ids" {
  description = "애플리케이션 ASG가 배치될 Private App 서브넷 ID 목록"
  type        = list(string)
}

variable "was_security_group_id" {
  description = "WAS 인스턴스에 적용할 보안그룹 ID"
  type        = string
}

variable "was_ami_id" {
  description = "WAS 인스턴스용 AMI ID"
  type        = string
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
  description = "WAS ASG 헬스체크 타입 (EC2 또는 ELB)"
  type        = string
  default     = "ELB"
}

variable "was_health_check_grace_period" {
  description = "WAS ASG 헬스체크 유예시간(초)"
  type        = number
  default     = 300
}

variable "was_user_data_base64" {
  description = "WAS Launch Template user_data (base64 인코딩 문자열). 없으면 null"
  type        = string
  default     = null
}

variable "was_iam_instance_profile_name" {
  description = "WAS 인스턴스에 연결할 IAM Instance Profile 이름. 없으면 null"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# AI ASG
# ------------------------------------------------------------------------------

variable "ai_security_group_id" {
  description = "AI 인스턴스에 적용할 보안그룹 ID"
  type        = string
}

variable "ai_ami_id" {
  description = "AI 인스턴스용 AMI ID"
  type        = string
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
  description = "AI ASG 헬스체크 타입 (EC2 또는 ELB)"
  type        = string
  default     = "ELB"
}

variable "ai_health_check_grace_period" {
  description = "AI ASG 헬스체크 유예시간(초)"
  type        = number
  default     = 300
}

variable "ai_user_data_base64" {
  description = "AI Launch Template user_data (base64 인코딩 문자열). 없으면 null"
  type        = string
  default     = null
}

variable "ai_iam_instance_profile_name" {
  description = "AI 인스턴스에 연결할 IAM Instance Profile 이름. 없으면 null"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Chat EC2
# ------------------------------------------------------------------------------

variable "chat_subnet_id" {
  description = "Chat 인스턴스가 배치될 서브넷 ID"
  type        = string
}

variable "chat_security_group_id" {
  description = "Chat 인스턴스에 적용할 보안그룹 ID"
  type        = string
}

variable "chat_ami_id" {
  description = "Chat 인스턴스용 AMI ID"
  type        = string
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
  default     = null
}

variable "chat_user_data_base64" {
  description = "Chat 인스턴스 user_data (base64 인코딩 문자열). 없으면 null"
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
