terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  # Remote state: uncomment and fill in once you have a state bucket.
  # backend "s3" {
  #   bucket         = "CHANGE-ME-tfstate"
  #   key            = "hardened-aws-web-tier/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "CHANGE-ME-tf-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Owner     = "hustlerx01"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}
