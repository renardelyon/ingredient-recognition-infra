# Ingredients Backend Terraform

This Terraform configuration provisions AWS infrastructure for the Ingredients Recognition backend application, including ECR repositories, Lambda functions, and CI/CD integration with GitHub Actions.

## Overview

This infrastructure provides:
- **Amazon ECR** - Container registry for Lambda function images
- **AWS Lambda** - Serverless compute for the recognition application
- **IAM Roles & Policies** - Secure permissions for Lambda and GitHub Actions
- **OIDC Provider** - GitHub Actions integration with AWS using OpenID Connect

## Prerequisites

- **Terraform** >= 1.2
- **AWS CLI** configured with appropriate credentials
- **AWS Account** with permissions to create:
  - ECR repositories
  - Lambda functions
  - IAM roles and policies
  - OIDC providers

## Usage

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Configure Variables

Create a `terraform.tfvars` file (or use command-line flags):

```hcl
aws_region  = "us-east-1"
project_name = "ingredients-recognition-app"
github_repo  = "owner/repo"  # GitHub repo in owner/repo format
```

### 3. Plan and Apply

```bash
# Preview changes
terraform plan

# Apply configuration
terraform apply
```

## Variables

| Name | Description | Default |
|------|-------------|---------|
| `aws_region` | AWS region | `us-east-1` |
| `project_name` | Project name (used for resource naming) | `ingredients-recognition-app` |
| `github_repo` | GitHub repository (format: owner/repo) | `renardelyon/rekognition-lambda` |

## Outputs

After applying, Terraform provides:

- `ecr_repository_url` - URL of the ECR repository
- `ecr_repository_name` - Name of the ECR repository
- `lambda_function_name` - Name of the Lambda function
- `lambda_function_role_arn` - ARN of the Lambda execution role
- `github_actions_role_arn` - ARN of the GitHub Actions role (add to GitHub secrets)

## Common Commands

```bash
# View current state
terraform show

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Destroy resources
terraform destroy

# View specific output
terraform output github_actions_role_arn
```