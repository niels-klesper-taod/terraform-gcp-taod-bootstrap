# Environment variables

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "europe-west2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Must be dev or prod."
  }
}

variable "terraform_backend_bucket" {
  description = "Backend bucket"
  type        = string
  default     = "terraform-bootstrap-base-infra"
}

# Workload Identity variables
variable "github_repository" {
  description = "GitHub repository for monorepo (e.g., 'myorg/nc-gcp-mvp')"
  type        = string
}

# Resource variables
