variable "region" {
  description = "AWS region. ap-south-1 is Mumbai."
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Name prefix for all resources."
  type        = string
  default     = "hardened-web"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of AZs (ALB needs at least 2)."
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "true = one NAT for all AZs (cheaper, less resilient). false = one per AZ."
  type        = bool
  default     = true
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "web_instance_count" {
  type    = number
  default = 2
}

variable "acm_certificate_arn" {
  description = "ACM cert for HTTPS. Leave empty to run HTTP-only (lab mode, see SECURITY_FINDINGS.md)."
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "owner/repo allowed to assume the CI role through OIDC."
  type        = string
  default     = "hustlerx01/hardened-aws-web-tier"
}

variable "github_branch" {
  description = "Only this branch may assume the role."
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Set false if the account already has token.actions.githubusercontent.com registered."
  type        = bool
  default     = true
}

variable "tf_state_bucket" {
  description = "Name of the S3 bucket holding Terraform state (CI role gets read access for plan)."
  type        = string
  default     = "CHANGE-ME-tfstate"
}

variable "log_retention_days" {
  type    = number
  default = 365
}
