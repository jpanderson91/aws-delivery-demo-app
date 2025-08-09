// Core Variables used by this stack

variable "project_name" {
  description = "Name of the project for resource naming and tagging"
  type        = string
  default     = "aws-delivery-demo-app"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "AWS named profile to use for credentials (supports SSO profiles)"
  type        = string
  default     = "aws-delivery-demo-app"
}

variable "owner" {
  description = "Owner of the resources for cost tracking and project management"
  type        = string
  default     = "Project Team"
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "Technology"
}

variable "ttl_days" {
  description = "Number of days before customer items expire (DynamoDB TTL)."
  type        = number
  default     = 7
}
