# Workload Identity Outputs for GitHub Actions

output "workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Workload Identity Provider resource name for GitHub Actions"
}

output "cicd_service_account_email" {
  value       = google_service_account.cicd.email
  description = "CI/CD Service Account email for GitHub Actions"
}

# Cloud Run Jobs Outputs

output "cloud_run_jobs_service_account" {
  value       = google_service_account.cloud_run_jobs.email
  description = "Service account email for Cloud Run Jobs"
}

# Artifact Registry Outputs

output "artifact_registry_repository" {
  value       = google_artifact_registry_repository.docker_repo.repository_id
  description = "Artifact Registry repository ID"
}

output "artifact_registry_url" {
  value       = "${google_artifact_registry_repository.docker_repo.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
  description = "Full Artifact Registry URL"
}

# Project Information Outputs

output "project_id" {
  value       = var.project_id
  description = "GCP Project ID"
}

output "project_number" {
  value       = data.google_project.project.number
  description = "GCP Project Number"
}

output "region" {
  value       = var.region
  description = "GCP Region"
}

output "environment" {
  value       = var.environment
  description = "Environment name"
}
