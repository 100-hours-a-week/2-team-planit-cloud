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

  vpc_id = module.network.vpc_id
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
  cloudfront_oai_iam_arn = var.cloudfront_oai_iam_arn
}
