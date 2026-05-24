terraform {
  required_version = "~> 1.5"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.16.0"
    }
  }
  
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "terraform_remote_state" "base" {
  backend = "gcs"
  
  config = {
    bucket = var.backend_bucket
    prefix = "base/${var.environment}"
  }
}

resource "google_cloud_run_v2_job" "job" {
  name     = "${var.environment}-${var.feature_name}-job"
  location = var.region

  template {
    template {
      containers {
        image = var.image_uri
        
        env {
          name  = "GCP_PROJECT"
          value = var.project_id
        }
        
        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }
      }
      
      service_account = data.terraform_remote_state.base.outputs.cloud_run_jobs_service_account
      timeout         = "3600s"
      max_retries     = 3
    }
  }
}

variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "feature_name" { type = string }
variable "image_uri" { type = string }
variable "backend_bucket" { type = string }

output "job_name" {
  value = google_cloud_run_v2_job.job.name
}
