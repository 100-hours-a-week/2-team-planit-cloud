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

  # Terraform Cloud 사용 시 아래 backend로 전환
  # backend "remote" {
  #   organization = "YOUR_ORG"
  #   workspaces {
  #     name = "planit-network"
  #   }
  # }
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
