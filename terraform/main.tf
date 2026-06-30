# Terraform configuration block
# Specifies Terraform version and required providers
terraform {
  required_version = "~> 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.16.0"
    }
  }

  # Backend configuration for storing Terraform state in Google Cloud Storage
  backend "gcs" {}
}


# Google Cloud provider configuration
# Sets up the default project, region, and labels for all resources
provider "google" {
  project = var.project_id
  region  = var.region

  # Default labels applied to ALL resources
  default_labels = {
    environment = var.environment
  }
}


# Enable required Google Cloud APIs
# Activates necessary services for Composer, Artifact Registry, Secret Manager,
# Cloud Run Jobs, and Workload Identity
resource "google_project_service" "required_apis" {
  for_each = toset([
    "artifactregistry.googleapis.com", # Docker image storage
    "secretmanager.googleapis.com",    # Secret management
    "run.googleapis.com",              # Cloud Run Jobs
    "iam.googleapis.com",              # Workload Identity
    "iamcredentials.googleapis.com",   # Workload Identity credentials
    "cloudscheduler.googleapis.com"    # Cloud Scheduler for cron triggers
  ])
  service = each.value
}


# Artifact Registry repository for Docker images
# Stores container images for Cloud Run Jobs
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = join("-", [var.environment, var.project_id])
  format        = "DOCKER"

  # Ensure APIs are enabled before creating the repository
  depends_on = [google_project_service.required_apis]
}


# Service Accounts
# Creates dedicated service accounts for different components

# Service account for Cloud Run Jobs execution
resource "google_service_account" "cloud_run_jobs" {
  account_id   = join("-", [var.environment, "cloud-run-jobs"])
  display_name = join("-", [var.environment, "cloud-run-jobs-service-account", var.project_id])
}

# Service account for Cloud Scheduler to invoke Cloud Run Jobs
resource "google_service_account" "scheduler" {
  account_id   = join("-", [var.environment, "scheduler"])
  display_name = join("-", [var.environment, "scheduler-service-account", var.project_id])
}

# Service account for CI/CD pipeline (GitHub Actions)
resource "google_service_account" "cicd" {
  account_id   = join("-", [var.environment, "cicd"])
  display_name = join("-", [var.environment, "cicd-service-account", var.project_id])
}

# IAM permissions for Cloud Run Jobs service account
# Grants access to BigQuery and Cloud Storage for data processing

# Allows Cloud Run Jobs to read and write BigQuery data
resource "google_project_iam_member" "cloud_run_jobs_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.cloud_run_jobs.email}"
}

# Allows Cloud Run Jobs to read from Cloud Storage
resource "google_project_iam_member" "cloud_run_jobs_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.cloud_run_jobs.email}"
}

# IAM permissions for CI/CD service account
# Grants permissions for GitHub Actions to deploy Cloud Run Jobs

# Allows CI/CD to push Docker images to Artifact Registry
resource "google_project_iam_member" "cicd_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# Allows CI/CD to manage Cloud Run resources
resource "google_project_iam_member" "cicd_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# Allows CI/CD to act as service accounts when deploying Cloud Run Jobs from GitHub Actions
resource "google_project_iam_member" "cicd_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# Workload Identity Federation for GitHub Actions
# Enables keyless authentication from GitHub Actions to GCP without service account keys

# Fetch project metadata for Workload Identity configuration
data "google_project" "project" {
  project_id = var.project_id
}

# Create Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "${var.environment}-github-pool"
  display_name              = "GitHub Actions Pool"

  depends_on = [google_project_service.required_apis]
}

# Configure GitHub as an OIDC identity provider
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"

  # Map GitHub token attributes to Google Cloud attributes
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  # Restrict access to specific GitHub repository owner
  attribute_condition = "assertion.repository_owner == '${split("/", var.github_repository)[0]}'"

  # GitHub OIDC token issuer
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  depends_on = [google_project_service.required_apis]
}

# Grant GitHub Actions permission to impersonate the CI/CD service account
resource "google_service_account_iam_member" "github_actions_workload_identity" {
  service_account_id = google_service_account.cicd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/attribute.repository/${var.github_repository}"
}


# Secret Manager for application secrets
# Stores sensitive configuration data securely
resource "google_secret_manager_secret" "app_secrets" {
  secret_id = join("-", [var.environment, "app-secret"])

  # Replication configuration - stores secrets in specific region
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  # Deletion protection disabled for easier cleanup in non-production environments
  deletion_protection = false
  depends_on          = [google_project_service.required_apis]
}
