# ------------------------------------------------------------------------------
# Terraform & Provider (루트)
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "remote" {
    organization = "planit"

    workspaces {
      name = "2-team-planit-cloud"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ------------------------------------------------------------------------------
# CloudFront OAI (신규 생성)
# ------------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_identity" "this" {
  comment = "${var.project}-${var.environment}-oai"
}

# ------------------------------------------------------------------------------
# Network 모듈 호출
# ------------------------------------------------------------------------------

module "network" {
  source = "./modules/network"

  environment = var.environment
  project     = var.project
  region      = var.region
  vpc_cidr    = var.vpc_cidr

  enable_nat_instance    = var.enable_nat_instance
  nat_instance_type      = var.nat_instance_type
  nat_instance_ami_id    = var.nat_instance_ami_id
  nat_instance_key_name  = var.nat_instance_key_name
}

# ------------------------------------------------------------------------------
# Security 모듈 (보안 그룹)
# ------------------------------------------------------------------------------

module "security" {
  source = "./modules/security"

  vpc_id      = module.network.vpc_id
  project     = var.project
  environment = var.environment

  ec2_assume_role_service     = var.ec2_assume_role_service
  ec2_ssm_managed_policy_arns = var.ec2_ssm_managed_policy_arns
  ec2_ssm_inline_policy_json  = var.ec2_ssm_inline_policy_json
  ec2_s3_managed_policy_arns  = var.ec2_s3_managed_policy_arns
  ec2_s3_inline_policy_json   = var.ec2_s3_inline_policy_json
}

# ------------------------------------------------------------------------------
# Storage 모듈 (DB EC2, EBS, S3)
# ------------------------------------------------------------------------------

module "storage" {
  source = "./modules/storage"

  environment           = var.environment
  project               = var.project
  private_db_subnet_ids = module.network.private_db_subnet_ids
  application_sg_id     = module.security.security_group_ids.db
  db_ami_id             = var.db_ami_id
  db_key_name           = var.db_key_name

  db_root_volume_size_gb = var.db_root_volume_size_gb
  db_data_volume_size_gb = var.db_data_volume_size_gb
}

# ------------------------------------------------------------------------------
# Compute 모듈 (WAS ASG)
# ------------------------------------------------------------------------------

module "compute" {
  source = "./modules/compute"

  environment = var.environment
  project     = var.project

  vpc_id                 = module.network.vpc_id
  public_subnet_ids      = module.network.public_subnet_ids
  private_app_subnet_ids = module.network.private_app_subnet_ids
  alb_security_group_id  = module.security.security_group_ids.alb
  was_security_group_id  = module.security.security_group_ids.be
  ai_security_group_id   = module.security.security_group_ids.ai
  cloudfront_s3_origin_domain_name = module.storage.fe_bucket_regional_domain_name
  cloudfront_s3_origin_path        = var.cloudfront_s3_origin_path
  cloudfront_oai_id                = aws_cloudfront_origin_access_identity.this.id
  cloudfront_aliases               = var.cloudfront_aliases
  cloudfront_acm_certificate_arn   = var.cloudfront_acm_certificate_arn
  cloudfront_minimum_protocol_version = var.cloudfront_minimum_protocol_version
  cloudfront_price_class              = var.cloudfront_price_class
  cloudfront_default_root_object      = var.cloudfront_default_root_object
  cloudfront_http_version             = var.cloudfront_http_version
  cloudfront_s3_image_origin_domain_name = var.cloudfront_s3_image_origin_domain_name
  cloudfront_image_path_patterns      = var.cloudfront_image_path_patterns
  route53_zone_name                   = var.route53_zone_name
  route53_record_name                 = var.route53_record_name
  route53_set_identifier              = var.route53_set_identifier
  route53_weight                      = var.route53_weight
  route53_evaluate_target_health      = var.route53_evaluate_target_health

  was_ami_id                     = var.was_ami_id
  was_instance_type              = var.was_instance_type
  was_key_name                   = var.was_key_name
  was_asg_min_size               = var.was_asg_min_size
  was_asg_desired_capacity       = var.was_asg_desired_capacity
  was_asg_max_size               = var.was_asg_max_size
  was_health_check_type          = var.was_health_check_type
  was_health_check_grace_period  = var.was_health_check_grace_period
  was_user_data_base64           = var.was_user_data_base64
  was_iam_instance_profile_name  = var.was_iam_instance_profile_name

  ai_ami_id                     = var.ai_ami_id
  ai_instance_type              = var.ai_instance_type
  ai_key_name                   = var.ai_key_name
  ai_asg_min_size               = var.ai_asg_min_size
  ai_asg_desired_capacity       = var.ai_asg_desired_capacity
  ai_asg_max_size               = var.ai_asg_max_size
  ai_health_check_type          = var.ai_health_check_type
  ai_health_check_grace_period  = var.ai_health_check_grace_period
  ai_user_data_base64           = var.ai_user_data_base64
  ai_iam_instance_profile_name  = var.ai_iam_instance_profile_name

  chat_subnet_id                 = module.network.private_app_subnet_ids[0]
  chat_security_group_id         = module.security.security_group_ids.be
  chat_ami_id                    = var.chat_ami_id
  chat_instance_type             = var.chat_instance_type
  chat_key_name                  = var.chat_key_name
  chat_iam_instance_profile_name = var.chat_iam_instance_profile_name
  chat_user_data_base64          = var.chat_user_data_base64
  chat_root_volume_size_gb       = var.chat_root_volume_size_gb
  chat_root_volume_type          = var.chat_root_volume_type
  chat_root_volume_encrypted     = var.chat_root_volume_encrypted
}

# ------------------------------------------------------------------------------
# 데이터 소스 (계정 ID 등)
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# FE S3 버킷 정책 (CloudFront 배포 ARN 방식 — 이미지와 동일)
# ------------------------------------------------------------------------------

resource "aws_s3_bucket_policy" "fe" {
  bucket = module.storage.fe_bucket_name

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "PolicyForCloudFrontPrivateContent"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::${module.storage.fe_bucket_name}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.compute.cloudfront_distribution_arn
          }
        }
      },
      {
        Sid       = "AllowCloudFrontOAI"
        Effect    = "Allow"
        Principal = { AWS = aws_cloudfront_origin_access_identity.this.iam_arn }
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::${module.storage.fe_bucket_name}/*"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# 이미지 업로드 S3 버킷 (planit-s3-bucket) — 기존 버킷 정책·CORS 관리
# ------------------------------------------------------------------------------

data "aws_s3_bucket" "image" {
  bucket = var.image_bucket_name
}

resource "aws_s3_bucket_policy" "image" {
  bucket = data.aws_s3_bucket.image.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFront"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${data.aws_s3_bucket.image.arn}/*"
        Condition = {
          ArnLike = {
            "AWS:SourceArn" = module.compute.cloudfront_distribution_arn
          }
        }
      },
      {
        Sid       = "AllowCloudFrontOAI"
        Effect    = "Allow"
        Principal = { AWS = aws_cloudfront_origin_access_identity.this.iam_arn }
        Action    = "s3:GetObject"
        Resource  = "${data.aws_s3_bucket.image.arn}/*"
      },
      {
        Sid       = "AllowIAMUserOrRole"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/planit-s3" }
        Action    = ["s3:GetObject", "s3:PutObject"]
        Resource  = "${data.aws_s3_bucket.image.arn}/*"
      },
      {
        Sid       = "AllowEC2RoleAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Planit-EC2-S3-Role" }
        Action    = ["s3:GetObject", "s3:PutObject"]
        Resource  = "${data.aws_s3_bucket.image.arn}/*"
      },
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${data.aws_s3_bucket.image.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.compute.cloudfront_distribution_arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_cors_configuration" "image" {
  bucket = data.aws_s3_bucket.image.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "HEAD"]
    allowed_origins = var.image_bucket_cors_origins
    expose_headers  = ["ETag"]
  }
}
