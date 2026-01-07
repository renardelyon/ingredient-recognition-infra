# Ingredients Backend Terraform

This Terraform configuration provisions AWS infrastructure for the Ingredients Recognition application, including backend and frontend deployments on EC2, Lambda functions for auto-off Rekognition, DynamoDB tables, and container registries.

## Overview

This infrastructure provides three main components:

### 1. Backend Application (`ingredient-recognition-backend/`)
- **Amazon ECR** - Container registry for backend application images
- **EC2 Instance** - Compute instance running the backend application with Docker
- **DynamoDB Tables** - NoSQL database for Users and Recipes data
- **IAM Roles & Policies** - Permissions for ECR, Bedrock, Rekognition, and DynamoDB access
- **Systems Manager (SSM)** - Automated deployment document for application updates
- **Nginx + Let's Encrypt** - Reverse proxy with automatic SSL certificate management
- **Elastic IP** - Static IP address for the backend instance

### 2. Frontend Application (`ingredient-recognition-frontend/`)
- **Amazon ECR** - Container registry for frontend application images
- **EC2 Instance** - Compute instance running the frontend application with Docker
- **IAM Roles & Policies** - Permissions for ECR access
- **Systems Manager (SSM)** - Automated deployment document for application updates
- **Nginx + Let's Encrypt** - Reverse proxy with automatic SSL certificate management
- **Elastic IP** - Static IP address for the frontend instance

### 3. Auto-Off Rekognition Lambda (`auto_off_rekognition_lambda/`)
- **Amazon ECR** - Container registry for Lambda function images
- **AWS Lambda** - Serverless function to automatically stop Rekognition projects
- **EventBridge Rules** - Scheduled triggers for Lambda execution
- **IAM Roles & Policies** - Permissions for Rekognition project management
- **OIDC Provider** - GitHub Actions integration with AWS using OpenID Connect

## Prerequisites

- **Terraform** >= 1.2
- **AWS CLI** configured with appropriate credentials
- **SSH Key Pair** - Public key at `~/.ssh/id_ed25519.pub` (or modify the path in configs)
- **AWS Account** with permissions to create:
  - EC2 instances
  - ECR repositories
  - DynamoDB tables
  - Lambda functions
  - IAM roles and policies
  - OIDC providers
  - EventBridge rules
  - Systems Manager documents
  - Elastic IPs

## Usage

### Backend Application

```bash
cd ingredient-recognition-backend

# Initialize Terraform
terraform init

# Configure variables (optional - defaults are provided)
# Create terraform.tfvars:
# aws_region = "us-east-1"
# service_name = "ingredients_recognition_backend"
# domain_name = "https://your-backend-domain.mooo.com"
# letsencrypt_email = "your-email@example.com"

# Preview changes
terraform plan

# Apply configuration
terraform apply
```

### Frontend Application

```bash
cd ingredient-recognition-frontend

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply configuration
terraform apply
```

### Auto-Off Rekognition Lambda

```bash
cd auto_off_rekognition_lambda

# Initialize Terraform
terraform init

# Configure variables
# Create terraform.tfvars:
# aws_region = "us-east-1"
# project_name = "ingredients-recognition-app"
# github_repo = "owner/repo"

# Preview changes
terraform plan

# Apply configuration
terraform apply
```


## Common Commands

```bash
# View current state
terraform show

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Destroy resources (per environment)
cd ingredient-recognition-backend
terraform destroy

# View specific output
terraform output ecr_repository_url

# Apply changes to specific module
terraform apply -target=module.dynamodb
```