# GCP MVP Project - Base Infrastructure

Base infrastructure for Cloud Run Job features deployed from a separate repository.

## Architecture Overview

This is a **multi-repo setup**:

- **This repo** (`nc-gcp-mvp`): Base infrastructure (Composer, Service Accounts, Workload Identity)
- **Features repo** (separate): Individual Cloud Run Job features with auto-deployment

```
Repository: nc-gcp-mvp (THIS REPO)
├── terraform/
│   ├── main.tf          # Base infrastructure
│   ├── outputs.tf       # Outputs for features to consume
│   ├── variables.tf
│   ├── backend/
│   │   └── dev.tfbackend
│   └── environment/
│       └── dev.tfvars

Repository: nc-gcp-features (SEPARATE REPO)
├── .github/workflows/
│   └── deploy-features.yml
└── features/
    ├── data-ingestion-a/
    ├── data-ingestion-b/
    └── example-feature/
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

- **Cloud Composer** - Managed Airflow for orchestration
- **Artifact Registry** - Docker image storage for features
- **Secret Manager** - Secure configuration storage
- **Workload Identity** - Keyless authentication for GitHub Actions
- **Service Accounts** - Dedicated accounts for Composer, Cloud Run Jobs, and CI/CD

### Outputs for Features

This infrastructure exposes outputs that features consume:

- `workload_identity_provider` - For GitHub Actions authentication
- `cicd_service_account_email` - CI/CD service account
- `cloud_run_jobs_service_account` - Runtime service account for jobs
- `artifact_registry_url` - Docker registry URL
- `composer_airflow_uri` - Airflow web UI URL
- `project_id`, `region`, `environment` - Project configuration

## Base Infrastructure

### Service Accounts

1. **Composer** (`{env}-composer-{project}`)
   - Role: `roles/composer.worker`
   - Role: `roles/run.invoker` (to invoke Cloud Run Jobs)
   - Purpose: Airflow orchestration

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
> See **[BOOTSTRAP.md](BOOTSTRAP.md)** for detailed bootstrap instructions.

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

> **📖 Detailed Instructions**: See [BOOTSTRAP.md](BOOTSTRAP.md) for complete bootstrap guide.

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
github_repository = "your-org/nc-gcp-features"  # Your FEATURES repo
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
- ✅ Cloud Composer environment (~15-20 minutes)
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
terraform output composer_airflow_uri
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
| `composer_airflow_uri` | Airflow web UI URL | Access Airflow UI |
| `composer_dag_gcs_prefix` | GCS path for DAGs | Upload DAGs |
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

## Features Repository Setup

### 1. Create Features Repository

Create a new repository (e.g., `nc-gcp-features`) with this structure:

```
nc-gcp-features/
├── .github/workflows/
│   └── deploy-features.yml      # CI/CD workflow
└── features/
    ├── example-feature/         # Template
    │   ├── terraform/main.tf
    │   ├── Dockerfile
    │   ├── main.py
    │   └── requirements.txt
    ├── data-ingestion-a/
    └── data-ingestion-b/
```

### 2. Add GitHub Secrets to Features Repo

In your **features repository**, add these secrets:

**Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `WORKLOAD_IDENTITY_PROVIDER` | Full WI provider path | `terraform output workload_identity_provider` (from this repo) |
| `SERVICE_ACCOUNT_EMAIL` | CI/CD service account email | `terraform output cicd_service_account_email` (from this repo) |
| `TERRAFORM_BACKEND_BUCKET` | GCS bucket name | Your state bucket name |
| `ENVIRONMENT` | Environment name | `dev` or `prod` |

### 3. Copy CI/CD Workflow

Copy the workflow template from this repo to your features repo:

```bash
# In features repo
mkdir -p .github/workflows

# Copy from this repo (or use the template in features/possible_cicd.yaml)
cp /path/to/nc-gcp-mvp/features/possible_cicd.yaml .github/workflows/deploy-features.yml

# Commit
git add .github/workflows/
git commit -m "Add CI/CD workflow"
git push
```

### 4. Add Features

```bash
# In features repo
cp -r features/example-feature features/my-new-feature

# Edit files
vim features/my-new-feature/main.py

# Push
git add features/my-new-feature
git commit -m "Add my-new-feature"
git push
```

**GitHub Actions will auto-detect and deploy!**

## How Features Connect

### Remote State Access

Features read base infrastructure outputs via Terraform remote state:

**In feature's `terraform/main.tf`:**

```hcl
# Read base infrastructure outputs
data "terraform_remote_state" "base" {
  backend = "gcs"
  config = {
    bucket = var.backend_bucket
    prefix = "base/${var.environment}"  # Points to THIS repo's state
  }
}

# Use outputs
resource "google_cloud_run_v2_job" "job" {
  # ...
  
  template {
    template {
      # Use service account from base infrastructure
      service_account = data.terraform_remote_state.base.outputs.cloud_run_jobs_service_account
      
      containers {
        # Image pushed to Artifact Registry from base infrastructure
        image = "${data.terraform_remote_state.base.outputs.artifact_registry_url}/${var.feature_name}:${var.image_tag}"
      }
    }
  }
}
```

### Authentication Flow

```
GitHub Actions (features repo)
    ↓
Authenticate via Workload Identity (from base infra)
    ↓
Impersonate CI/CD Service Account (from base infra)
    ↓
Push to Artifact Registry (from base infra)
    ↓
Deploy Cloud Run Job with Runtime SA (from base infra)
```

### Triggering from Composer

Airflow (from base infra) triggers Cloud Run Jobs (from features repo):

```python
from airflow.providers.google.cloud.operators.cloud_run import CloudRunExecuteJobOperator

run_job = CloudRunExecuteJobOperator(
    task_id='run_data_ingestion',
    project_id='your-project',
    region='europe-west2',
    job_name='dev-data-ingestion-a-job',  # Deployed from features repo
)
```

## State Storage

### State Organization

```
gs://your-terraform-state-bucket/
├── base/
│   └── dev/
│       └── default.tfstate          # THIS REPO - Base infrastructure
└── features/
    ├── data-ingestion-a/dev/
    │   └── default.tfstate          # Features repo - Feature A
    ├── data-ingestion-b/dev/
    │   └── default.tfstate          # Features repo - Feature B
    └── my-new-feature/dev/
        └── default.tfstate          # Features repo - Your feature
```

### State Access

- **Base state** (`base/dev/default.tfstate`): Written by this repo, read by features repo
- **Feature states** (`features/*/dev/default.tfstate`): Written and read by features repo

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
- ✅ Cloud Composer environment
- ✅ Artifact Registry repository
- ✅ Service accounts and IAM
- ✅ Workload Identity Federation
- ✅ Secret Manager secrets
- ✅ Shared infrastructure

**Does NOT manage:**
- ❌ Individual Cloud Run Jobs
- ❌ Feature code
- ❌ Feature deployments

### Features Repo

**Manages:**
- ✅ Individual Cloud Run Jobs
- ✅ Feature code (Python, etc.)
- ✅ Feature Dockerfiles
- ✅ Feature dependencies
- ✅ Feature-specific Terraform

**Does NOT manage:**
- ❌ Base infrastructure
- ❌ Service accounts
- ❌ Artifact Registry
- ❌ Composer

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

### Composer Not Accessible

**Check:**
- Composer deployment completed (15-20 minutes)
- Get Airflow URI: `terraform output composer_airflow_uri`
- Check IAM permissions for your user account

## Example: Complete Setup

### Step 1: Deploy Base (This Repo)

```bash
# Clone this repo
git clone https://github.com/your-org/nc-gcp-mvp.git
cd nc-gcp-mvp/terraform

# Configure
cp backend/dev.tfbackend.example backend/dev.tfbackend
cp environment/dev.tfvars.example environment/dev.tfvars
vim environment/dev.tfvars  # Set github_repository to features repo!

# Deploy
terraform init -backend-config=backend/dev.tfbackend
terraform apply -var-file=environment/dev.tfvars

# Get outputs
terraform output > ../base-outputs.txt
```

### Step 2: Setup Features Repo

```bash
# Create/clone features repo
git clone https://github.com/your-org/nc-gcp-features.git
cd nc-gcp-features

# Copy template files from base repo
cp -r ../nc-gcp-mvp/features .
mkdir -p .github/workflows
cp features/possible_cicd.yaml .github/workflows/deploy-features.yml

# Add GitHub secrets (from base-outputs.txt)
# - WORKLOAD_IDENTITY_PROVIDER
# - SERVICE_ACCOUNT_EMAIL
# - TERRAFORM_BACKEND_BUCKET
# - ENVIRONMENT

# Commit
git add .
git commit -m "Initial setup"
git push
```

### Step 3: Add First Feature

```bash
# In features repo
cp -r features/example-feature features/my-feature
vim features/my-feature/main.py

git add features/my-feature
git commit -m "Add my-feature"
git push

# GitHub Actions automatically deploys!
```

## Summary

### What This Repo Provides

- **Shared Infrastructure**: Composer, Artifact Registry, Service Accounts
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
