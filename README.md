# GCP Ingestion Base Infrastructure Template

Base infrastructure template for Cloud Run Job ingestion features deployed from a separate repository.

## Multi-Repo Setup

This project follows a **multi-repo pattern** to separate concerns between platform infrastructure and feature deployments:

- **This repo** (`terraform-gcp-taod-bootstrap`): Base infrastructure (Cloud Scheduler, Service Accounts, Workload Identity, Artifact Registry) – deployed per environment
- **Features repo** (`terraform-gcp-features`): Individual Cloud Run Job ingestion features with auto-deployment via GitHub Actions

### Repository Structure

```
Repository: terraform-gcp-taod-bootstrap (THIS REPO)
├── docs/
│   └── BOOTSTRAP.md         # Bootstrap guide for first-time setup
├── terraform/
│   ├── main.tf                # Base infrastructure (SAs, IAM, WI, Scheduler)
│   ├── outputs.tf             # Outputs for features to consume
│   ├── variables.tf           # Input variables
│   ├── backend/
│   │   └── dev.tfbackend      # GCS state backend config
│   └── environment/
│       └── dev.tfvars         # Environment-specific variables

Repository: terraform-gcp-features (SEPARATE REPO)
├── .github/workflows/
│   └── deploy-features.yml    # CI/CD: build, push, deploy
├── Dockerfile                 # Shared Dockerfile at root
├── requirements.txt           # Shared Python dependencies
├── terraform/
│   └── main.tf                # Feature Cloud Run Job + Scheduler cron
└── features/
    ├── data-ingestion-a/
    │   └── main.py
    ├── data-ingestion-b/
    │   └── main.py
    └── example-feature/
        └── main.py
```

## Table of Contents

- [What This Repo Provides](#what-this-repo-provides)
- [Base Infrastructure](#base-infrastructure)
- [Quick Start](#quick-start)
- [Outputs](#outputs)
- [Features Repository Setup](#features-repository-setup)
- [How Features Connect](#how-features-connect)
- [State Storage](#state-storage)
- [Updating Infrastructure](#updating-infrastructure)

## What This Repo Provides

### Infrastructure Components

- **Cloud Scheduler** - Managed cron service for triggering Cloud Run Jobs
- **Artifact Registry** - Docker image storage for features
- **Secret Manager** - Secure configuration storage
- **Workload Identity** - Keyless authentication for GitHub Actions
- **Service Accounts** - Dedicated accounts for Cloud Run Jobs, Scheduler, and CI/CD

### Outputs for Features

This infrastructure exposes outputs that features consume:

- `workload_identity_provider` - For GitHub Actions authentication
- `cicd_service_account_email` - CI/CD service account
- `cloud_run_jobs_service_account` - Runtime service account for jobs
- `artifact_registry_url` - Docker registry URL
- `scheduler_service_account_email` - Service account for Cloud Scheduler to invoke jobs
- `project_id`, `region`, `environment` - Project configuration

## Base Infrastructure

### Service Accounts

1. **Scheduler** (`{env}-scheduler`)
   - Role: `roles/run.invoker` (to invoke Cloud Run Jobs)
   - Purpose: Cloud Scheduler cron triggers

2. **Cloud Run Jobs** (`{env}-cloud-run-jobs`)
   - Role: `roles/bigquery.dataEditor`
   - Role: `roles/storage.objectViewer`
   - Purpose: Runtime execution of jobs

3. **CI/CD** (`{env}-cicd`)
   - Role: `roles/artifactregistry.writer`
   - Role: `roles/run.admin`
   - Role: `roles/iam.serviceAccountUser`
   - Purpose: GitHub Actions deployment from features repo

### Workload Identity Federation

Enables keyless authentication from GitHub Actions:

- **Identity Pool**: `{env}-github-pool`
- **Provider**: `github-provider`
- **Configured for**: Your features repository
- **Security**: Restricted to specific repository owner

## Quick Start

### Prerequisites

- Google Cloud Project
- `gcloud` CLI installed and authenticated
- GitHub repository for features (will be configured)

> **⚠️ First Time Setup?** You need to create a GCS bucket for Terraform state first.  
> See **[docs/BOOTSTRAP.md](docs/BOOTSTRAP.md)** for detailed bootstrap instructions.

### 1. Bootstrap (First Time Only)

**If this is your first time**, you need to create the GCS bucket for Terraform state:

```bash
# Create bucket for Terraform state
export PROJECT_ID="your-project-id"
export BUCKET_NAME="terraform-state-${PROJECT_ID}"

gcloud storage buckets create gs://${BUCKET_NAME} \
  --project=${PROJECT_ID} \
  --location=europe-west2 \
  --uniform-bucket-level-access

# Enable versioning
gcloud storage buckets update gs://${BUCKET_NAME} --versioning
```

> **📖 Detailed Instructions**: See [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) for complete bootstrap guide.

### 2. Configure Backend

```bash
cd terraform

# Copy backend configuration
cp backend/dev.tfbackend.example backend/dev.tfbackend

# Edit with your GCS bucket
vim backend/dev.tfbackend
```

**backend/dev.tfbackend:**
```hcl
bucket = "terraform-state-your-project-id"  # Bucket created in bootstrap
prefix = "base/dev"
```

### 3. Configure Variables

```bash
# Copy environment configuration
cp environment/dev.tfvars.example environment/dev.tfvars

# Edit with your project details
vim environment/dev.tfvars
```

**environment/dev.tfvars:**
```hcl
project_id         = "your-gcp-project-id"
region            = "europe-west2"
environment       = "dev"
github_repository = "your-org/terraform-gcp-features"  # Your FEATURES repo
```

> **Important**: `github_repository` should point to your **features repository**, not this one!

### 4. Deploy Base Infrastructure

```bash
# Initialize Terraform
terraform init -backend-config=backend/dev.tfbackend

# Review plan
terraform plan -var-file=environment/dev.tfvars

# Deploy
terraform apply -var-file=environment/dev.tfvars
```

This will create:
- ✅ Cloud Scheduler service account
- ✅ Artifact Registry repository
- ✅ Service accounts with IAM bindings
- ✅ Workload Identity pool and provider
- ✅ Secret Manager secret

### 5. Get Outputs

After deployment, get the outputs needed for your features repository:

```bash
# Get all outputs
terraform output

# Get specific outputs
terraform output workload_identity_provider
terraform output cicd_service_account_email
terraform output artifact_registry_url
terraform output scheduler_service_account_email
```

**Save these values** - you'll need them for the features repository setup.

## Outputs

### Complete Output Reference

| Output | Description | Used By |
|--------|-------------|---------|
| `workload_identity_provider` | Full resource name of Workload Identity Provider | Features repo GitHub secret |
| `cicd_service_account_email` | Email of CI/CD service account | Features repo GitHub secret |
| `cloud_run_jobs_service_account` | Email of Cloud Run Jobs service account | Feature Terraform (via remote state) |
| `artifact_registry_url` | Docker registry URL | Feature CI/CD (via remote state) |
| `scheduler_service_account_email` | Service account for Cloud Scheduler | Feature Terraform (via remote state) |
| `project_id` | GCP Project ID | Feature Terraform (via remote state) |
| `region` | GCP Region | Feature Terraform (via remote state) |
| `environment` | Environment name | Feature Terraform (via remote state) |

### Viewing Outputs

```bash
cd terraform

# All outputs
terraform output

# Specific output
terraform output workload_identity_provider

# JSON format (for scripting)
terraform output -json
```

## State Storage

```
gs://your-terraform-state-bucket/
├── base/
│   └── dev/
│       └── default.tfstate          # THIS REPO - Base infrastructure
└── features/
    ├── data-ingestion-a/dev/
    │   └── default.tfstate          # Features repo - Feature A
    └── data-ingestion-b/dev/
        └── default.tfstate          # Features repo - Feature B
```

- **Base state** (`base/dev/...`): Written by this repo, read by features repo
- **Feature states** (`features/*/dev/...`): Written and read by features repo

## Updating Infrastructure

### Updating Base Infrastructure

```bash
# In this repo
cd terraform

# Make changes
vim main.tf

# Apply
terraform plan -var-file=environment/dev.tfvars
terraform apply -var-file=environment/dev.tfvars
```

**Note**: Changes to outputs will be automatically picked up by features on their next deployment.

### Adding New Outputs

If you add new outputs that features need:

1. Add to `outputs.tf` in this repo
2. Apply changes: `terraform apply`
3. Features can now read the new output via remote state

### Updating Service Account Permissions

```bash
# Edit main.tf
vim terraform/main.tf

# Add new IAM binding
resource "google_project_iam_member" "cloud_run_jobs_new_permission" {
  project = var.project_id
  role    = "roles/some.newRole"
  member  = "serviceAccount:${google_service_account.cloud_run_jobs.email}"
}

# Apply
terraform apply -var-file=environment/dev.tfvars
```

## Repository Responsibilities

### This Repo (Base Infrastructure)

**Manages:**
- ✅ Cloud Scheduler service account
- ✅ Artifact Registry repository
- ✅ Service accounts and IAM
- ✅ Workload Identity Federation
- ✅ Secret Manager secrets
- ✅ Shared infrastructure

**Does NOT manage:**
- ❌ Individual Cloud Run Jobs
- ❌ Feature code
- ❌ Feature deployments

## Benefits of Multi-Repo Setup

### ✅ Separation of Concerns

- **Infrastructure team**: Manages base infrastructure (this repo)
- **Feature teams**: Deploy features independently (features repo)

### ✅ Independent Lifecycles

- Update base infrastructure without touching features
- Deploy features without infrastructure changes
- Different deployment frequencies

### ✅ Access Control

- Restrict base infrastructure changes to platform team
- Allow feature teams full access to features repo
- Clear ownership boundaries

### ✅ Faster CI/CD

- Features repo CI/CD only runs for feature changes
- Base infrastructure changes don't trigger feature deployments
- Smaller, focused repositories

## Troubleshooting

### Features Can't Read Remote State

**Check:**
- Base infrastructure is deployed: `terraform output` (in this repo)
- State bucket and prefix match in both repos
- Features repo uses correct `backend_bucket` variable

### Workload Identity Authentication Failed

**Check:**
- `github_repository` in base Terraform matches features repo (not this repo!)
- Format: `owner/repo-name` (e.g., `myorg/nc-gcp-features`)
- Features repo secrets are correct (from base outputs)

### Service Account Permissions Missing

**Check:**
- IAM bindings in this repo's `main.tf`
- Run `terraform apply` in this repo after changes
- Wait a few minutes for IAM propagation

### Scheduler Not Accessible

**Check:**
- Cloud Scheduler API is enabled: `gcloud services list --enabled | grep scheduler`
- Service account has `roles/run.invoker` permission
- Check IAM permissions for your user account

## Summary

### What This Repo Provides

- **Shared Infrastructure**: Cloud Scheduler, Artifact Registry, Service Accounts
- **Authentication**: Workload Identity for keyless GitHub Actions
- **Outputs**: Configuration for features to consume
- **Foundation**: Secure, scalable base for unlimited features

### Next Steps

1. ✅ Deploy this base infrastructure
2. ✅ Get outputs: `terraform output`
3. ✅ Create features repository
4. ✅ Add GitHub secrets to features repo
5. ✅ Copy CI/CD workflow to features repo
6. ✅ Start adding features!

### Key Points

- **This repo**: Base infrastructure only
- **Features repo**: Individual Cloud Run Jobs
- **Connection**: Remote state + Workload Identity
- **Deployment**: Independent lifecycles
- **Security**: Keyless authentication, least privilege

---

**Ready to add features?** Set up your features repository and start deploying! 🚀
