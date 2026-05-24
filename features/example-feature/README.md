# Example Feature

This is a template for creating new Cloud Run Job features.

## Setup

1. **Copy this folder** to your new feature repository
2. **Configure GitHub Secrets**:
   - `WORKLOAD_IDENTITY_PROVIDER` - from base infrastructure output
   - `SERVICE_ACCOUNT_EMAIL` - from base infrastructure output
   - `TERRAFORM_BACKEND_BUCKET` - your terraform state bucket
   - `ENVIRONMENT` - `dev` or `prod`

3. **Repository name becomes feature name** automatically
   - Repo: `data-ingestion-a` → Feature: `data-ingestion-a`
   - Job name: `dev-data-ingestion-a-job`

## How it works

1. Push to `main` branch
2. GitHub Actions authenticates via Workload Identity (no keys!)
3. Reads base infrastructure outputs from remote state
4. Builds and pushes Docker image to Artifact Registry
5. Deploys Cloud Run Job using Terraform

## State Storage

Feature state is stored at:
```
gs://BUCKET/features/FEATURE_NAME/ENVIRONMENT/default.tfstate
```

Example:
```
gs://terraform-bootstrap-base-infra/features/data-ingestion-a/dev/default.tfstate
```

## Triggering from Composer

```python
from airflow.providers.google.cloud.operators.cloud_run import CloudRunExecuteJobOperator

run_job = CloudRunExecuteJobOperator(
    task_id='run_data_ingestion',
    project_id='your-project',
    region='europe-west2',
    job_name='dev-data-ingestion-a-job',
)
```
