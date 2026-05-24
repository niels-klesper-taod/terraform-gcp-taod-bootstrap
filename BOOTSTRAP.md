# Bootstrap Guide

This guide helps you set up the initial prerequisites before deploying the base infrastructure.

## The Bootstrap Problem

You need:
1. **GCS bucket** for Terraform state storage
2. **GitHub Workload Identity** for keyless authentication

But:
- Terraform needs a state bucket to store its state
- Workload Identity is created BY Terraform
- You can't create the bucket with Terraform if Terraform needs the bucket first!

## Solution: Two-Step Bootstrap

### Option A: Manual Bootstrap (Recommended for First Time)

Use `gcloud` CLI to create initial resources, then let Terraform manage everything else.

### Option B: Local State Bootstrap

Use local Terraform state initially, then migrate to GCS.

---

## Option A: Manual Bootstrap (Recommended)

### Prerequisites

- Google Cloud Project
- `gcloud` CLI installed and authenticated
- Project Owner or Editor role

### Step 1: Authenticate with GCP

```bash
# Login
gcloud auth login

# Set project
gcloud config set project YOUR-PROJECT-ID

# Verify
gcloud config get-value project
```

### Step 2: Enable Required APIs

```bash
# Enable APIs needed for bootstrap
gcloud services enable storage.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

### Step 3: Create GCS Bucket for Terraform State

```bash
# Set variables
export PROJECT_ID="your-project-id"
export REGION="europe-west2"
export BUCKET_NAME="terraform-state-${PROJECT_ID}"

# Create bucket
gcloud storage buckets create gs://${BUCKET_NAME} \
  --project=${PROJECT_ID} \
  --location=${REGION} \
  --uniform-bucket-level-access

# Enable versioning (recommended for state files)
gcloud storage buckets update gs://${BUCKET_NAME} \
  --versioning

# Verify
gcloud storage buckets describe gs://${BUCKET_NAME}
```

**Important**: Save the bucket name! You'll need it for Terraform backend configuration.

### Step 4: Configure Terraform Backend

```bash
cd terraform

# Copy backend config
cp backend/dev.tfbackend.example backend/dev.tfbackend

# Edit with your bucket name
cat > backend/dev.tfbackend <<EOF
bucket = "${BUCKET_NAME}"
prefix = "base/dev"
EOF
```

### Step 5: Configure Terraform Variables

```bash
# Copy variables
cp environment/dev.tfvars.example environment/dev.tfvars

# Edit with your values
vim environment/dev.tfvars
```

**environment/dev.tfvars:**
```hcl
project_id         = "your-project-id"
region            = "europe-west2"
environment       = "dev"
github_repository = "your-org/your-features-repo"  # Your FEATURES repo
```

### Step 6: Deploy Base Infrastructure

```bash
# Initialize Terraform with the backend
terraform init -backend-config=backend/dev.tfbackend

# Review plan
terraform plan -var-file=environment/dev.tfvars

# Deploy (creates Workload Identity, Composer, etc.)
terraform apply -var-file=environment/dev.tfvars
```

### Step 7: Get Outputs for Features Repo

```bash
# Get all outputs
terraform output

# Save important outputs
terraform output workload_identity_provider > ../workload-identity-provider.txt
terraform output cicd_service_account_email > ../cicd-service-account.txt

# Display for copying
echo "=== GitHub Secrets for Features Repo ==="
echo "WORKLOAD_IDENTITY_PROVIDER=$(terraform output -raw workload_identity_provider)"
echo "SERVICE_ACCOUNT_EMAIL=$(terraform output -raw cicd_service_account_email)"
echo "TERRAFORM_BACKEND_BUCKET=${BUCKET_NAME}"
echo "ENVIRONMENT=dev"
```

### Done! ✅

You now have:
- ✅ GCS bucket for Terraform state
- ✅ Base infrastructure deployed
- ✅ Workload Identity configured
- ✅ Outputs ready for features repo

---

## Option B: Local State Bootstrap

Use this if you want Terraform to create the bucket, then migrate state.

### Step 1: Create Bootstrap Terraform

Create a separate bootstrap configuration:

```bash
mkdir -p bootstrap
cd bootstrap
```

**bootstrap/main.tf:**
```hcl
terraform {
  required_version = "~> 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.16.0"
    }
  }
  # No backend - uses local state
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable Storage API
resource "google_project_service" "storage" {
  service = "storage.googleapis.com"
}

# Create state bucket
resource "google_storage_bucket" "terraform_state" {
  name          = "terraform-state-${var.project_id}"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.storage]
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

output "bucket_name" {
  value = google_storage_bucket.terraform_state.name
}
```

**bootstrap/terraform.tfvars:**
```hcl
project_id = "your-project-id"
region     = "europe-west2"
```

### Step 2: Run Bootstrap

```bash
cd bootstrap

# Authenticate
gcloud auth application-default login

# Initialize (local state)
terraform init

# Create bucket
terraform apply

# Get bucket name
BUCKET_NAME=$(terraform output -raw bucket_name)
echo "Bucket created: ${BUCKET_NAME}"
```

### Step 3: Configure Main Terraform

```bash
cd ../terraform

# Configure backend with the created bucket
cat > backend/dev.tfbackend <<EOF
bucket = "${BUCKET_NAME}"
prefix = "base/dev"
EOF

# Configure variables
cp environment/dev.tfvars.example environment/dev.tfvars
vim environment/dev.tfvars
```

### Step 4: Deploy Base Infrastructure

```bash
# Initialize with remote backend
terraform init -backend-config=backend/dev.tfbackend

# Deploy
terraform apply -var-file=environment/dev.tfvars
```

### Step 5: (Optional) Migrate Bootstrap State

If you want to manage the bucket with Terraform too:

```bash
# Copy bootstrap state to GCS
cd ../bootstrap
terraform init -migrate-state -backend-config=- <<EOF
bucket = "${BUCKET_NAME}"
prefix = "bootstrap/dev"
EOF
```

---

## What Gets Created

### By Bootstrap (Manual or Local)

- **GCS Bucket** (`terraform-state-{project-id}`)
  - Location: Your specified region
  - Versioning: Enabled
  - Uniform bucket-level access: Enabled

### By Base Infrastructure Terraform

- **Cloud Composer** environment
- **Artifact Registry** repository
- **Service Accounts** (3):
  - Composer
  - Cloud Run Jobs
  - CI/CD
- **IAM Bindings** for service accounts
- **Workload Identity Pool** and Provider
- **Secret Manager** secret

---

## Verification Checklist

After bootstrap and deployment:

### ✅ GCS Bucket

```bash
# List buckets
gcloud storage buckets list --project=YOUR-PROJECT-ID

# Check state file exists
gcloud storage ls gs://terraform-state-YOUR-PROJECT-ID/base/dev/
```

### ✅ Terraform State

```bash
cd terraform

# Should show resources
terraform state list

# Should show outputs
terraform output
```

### ✅ Workload Identity

```bash
# List identity pools
gcloud iam workload-identity-pools list --location=global

# List providers
gcloud iam workload-identity-pools providers list \
  --workload-identity-pool=dev-github-pool \
  --location=global
```

### ✅ Service Accounts

```bash
# List service accounts
gcloud iam service-accounts list --project=YOUR-PROJECT-ID

# Should see:
# - dev-composer-{project}@...
# - dev-cloud-run-jobs@...
# - dev-cicd@...
```

### ✅ Composer

```bash
# List Composer environments
gcloud composer environments list --locations=YOUR-REGION

# Get Airflow URI
terraform output composer_airflow_uri
```

---

## Troubleshooting Bootstrap

### "Bucket already exists"

```bash
# Check if bucket exists
gcloud storage buckets describe gs://terraform-state-YOUR-PROJECT-ID

# If it exists and you own it, use it
# Update backend/dev.tfbackend with the bucket name
```

### "API not enabled"

```bash
# Enable required APIs
gcloud services enable storage.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

### "Permission denied"

```bash
# Check your permissions
gcloud projects get-iam-policy YOUR-PROJECT-ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR-EMAIL"

# You need at least:
# - roles/storage.admin (for bucket creation)
# - roles/iam.admin (for Workload Identity)
# Or roles/owner / roles/editor
```

### "Cannot authenticate application-default credentials"

```bash
# Re-authenticate
gcloud auth application-default login

# Or use service account
gcloud auth activate-service-account --key-file=path/to/key.json
```

---

## Security Best Practices

### State Bucket Security

```bash
# The bucket should have:
# ✅ Uniform bucket-level access
# ✅ Versioning enabled
# ✅ Limited access (only Terraform users/SAs)

# Check bucket IAM
gcloud storage buckets get-iam-policy gs://terraform-state-YOUR-PROJECT-ID
```

### Workload Identity Security

- ✅ Restricts to specific GitHub repository owner
- ✅ No service account keys needed
- ✅ Short-lived tokens only
- ✅ Audit logs enabled

### Service Account Keys

**⚠️ IMPORTANT**: Never commit service account keys to git!

```bash
# If you have keys in auth/ directory
echo "auth/" >> .gitignore

# Remove from git if already committed
git rm --cached auth/service-account-key.json
git commit -m "Remove service account key"
```

---

## Multi-Environment Setup

For production environment:

### 1. Create Production Bucket

```bash
export ENV="prod"
export BUCKET_NAME="terraform-state-${PROJECT_ID}"  # Can use same bucket

# If using same bucket, just different prefix
# No need to create new bucket

# If using separate bucket
gcloud storage buckets create gs://terraform-state-${PROJECT_ID}-prod \
  --project=${PROJECT_ID} \
  --location=${REGION} \
  --uniform-bucket-level-access
```

### 2. Create Production Config

```bash
cd terraform

# Backend config
cat > backend/prod.tfbackend <<EOF
bucket = "terraform-state-${PROJECT_ID}"
prefix = "base/prod"
EOF

# Variables
cp environment/dev.tfvars environment/prod.tfvars
vim environment/prod.tfvars  # Change environment = "prod"
```

### 3. Deploy Production

```bash
# Use separate workspace or directory
terraform init -backend-config=backend/prod.tfbackend
terraform apply -var-file=environment/prod.tfvars
```

---

## Quick Reference

### Bootstrap Commands (Manual)

```bash
# 1. Create bucket
gcloud storage buckets create gs://terraform-state-YOUR-PROJECT \
  --location=YOUR-REGION --uniform-bucket-level-access

# 2. Configure backend
echo 'bucket = "terraform-state-YOUR-PROJECT"' > terraform/backend/dev.tfbackend
echo 'prefix = "base/dev"' >> terraform/backend/dev.tfbackend

# 3. Deploy
cd terraform
terraform init -backend-config=backend/dev.tfbackend
terraform apply -var-file=environment/dev.tfvars
```

### Get Outputs for Features Repo

```bash
cd terraform
terraform output -json | jq -r '
  "WORKLOAD_IDENTITY_PROVIDER=" + .workload_identity_provider.value,
  "SERVICE_ACCOUNT_EMAIL=" + .cicd_service_account_email.value,
  "TERRAFORM_BACKEND_BUCKET=terraform-state-YOUR-PROJECT",
  "ENVIRONMENT=dev"
'
```

---

## Next Steps

After bootstrap is complete:

1. ✅ Save the bucket name
2. ✅ Get Terraform outputs
3. ✅ Set up features repository
4. ✅ Add GitHub secrets to features repo
5. ✅ Start deploying features!

See main [README.md](README.md) for features repository setup.
