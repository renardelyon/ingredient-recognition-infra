provider "aws" {
  region = var.aws_region
}

# Get AWS account ID
data "aws_caller_identity" "current" {}

# VPC (using default VPC for simplicity)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

module "aws_ecr" {
  source = "../modules/ecr"

  app_name = "ingredients_recognition_frontend"
  lifecycle_policy = {
    description = "Keep last 10 images"
    quantity    = 10
  }
}

module "ec2_instance" {
  source = "../modules/ec2"

  aws_region = var.aws_region
  ami_type   = ["al2023-ami-*-x86_64"]
  app_name   = var.project_name
  aws_security_group_var = {
    vpc_id         = data.aws_vpc.default.id
    ssh_allowed_ip = "0.0.0.0/0"
    app_port       = var.app_port
  }
  app_port                       = var.app_port
  container_port                 = var.container_port
  aws_caller_identity_account_id = data.aws_caller_identity.current.account_id
  use_elastic_ip                 = true
  instance_type                  = "t3.micro"
  subnet_id                      = data.aws_subnets.default.ids[0]
  keypair_creation_config = {
    create_key_pair = true
    public_key      = file("~/.ssh/id_ed25519.pub")
  }

  iam_policies = local.iam_policies

  # Nginx + Let's Encrypt
  # For the first instance creation, set enable_nginx_ssl to false.
  # After the instance is created, update the variable to true and apply again with.
  enable_nginx_ssl  = var.enable_nginx_ssl
  domain_name       = var.domain_name
  letsencrypt_email = var.letsencrypt_email
}

# OIDC Provider for GitHub Actions (use existing provider)
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  iam_policies = {
    ecr = {
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage"
            ]
            Resource = "*"
          }
        ]
      })
    }
  }
}


# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
  })
}

module "ssm" {
  source                 = "../modules/ssm"
  ssm_attached_role_name = module.ec2_instance.ec2_role_name
  project_name           = var.project_name
  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Deploy ${var.project_name} application"
    parameters = {
      AWSRegion = {
        type        = "String"
        description = "AWS Region"
      }
      ECRRepository = {
        type        = "String"
        description = "ECR Repository name"
      }
      AppName = {
        type        = "String"
        description = "Application container name"
      }
    }
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "deployApplication"
        inputs = {
          runCommand = [
            "#!/bin/bash",
            "set -e",
            "",
            "AWS_REGION='{{AWSRegion}}'",
            "ECR_REPOSITORY='{{ECRRepository}}'",
            "APP_NAME='{{AppName}}'",
            "",
            "ECR_URL=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com",
            "",
            "echo '🔐 Logging in to ECR...'",
            "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL",
            "",
            "echo '📥 Pulling latest image...'",
            "docker pull $ECR_URL/$ECR_REPOSITORY:latest",
            "",
            "echo '🛑 Stopping existing container...'",
            "docker stop $APP_NAME || true",
            "docker rm $APP_NAME || true",
            "",
            "echo '🚀 Starting new container with environment variables...'",
            "docker run -d \\",
            "  --name $APP_NAME \\",
            "  --restart unless-stopped \\",
            "  -p 3000:80 \\",
            "  $ECR_URL/$ECR_REPOSITORY:latest",
            "",
            "echo '⏳ Waiting for container to be ready...'",
            "sleep 5",
            "",
            "echo '✅ Checking container status...'",
            "docker ps --filter name=$APP_NAME",
            "",
            "echo '🔍 Verifying deployment...'",
            "MAX_RETRIES=12",
            "RETRY_INTERVAL=5",
            "RETRY_COUNT=0",
            "",
            "while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do",
            "  if ! docker ps --filter name=$APP_NAME --filter status=running | grep -q $APP_NAME; then",
            "    echo '❌ Container is not running!'",
            "    echo '📋 Container logs:'",
            "    docker logs --tail 50 $APP_NAME || true",
            "    exit 1",
            "  fi",
            "",
            "  if curl -sf http://localhost:3000 > /dev/null 2>&1; then",
            "    echo '✅ Health check passed! Deployment successful.'",
            "    break",
            "  fi",
            "",
            "  RETRY_COUNT=$((RETRY_COUNT + 1))",
            "  if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then",
            "    echo '❌ Health check failed after $MAX_RETRIES attempts!'",
            "    echo '📋 Container logs:'",
            "    docker logs --tail 50 $APP_NAME || true",
            "    exit 1",
            "  fi",
            "",
            "  echo \"⏳ Waiting for app to be ready... (attempt $RETRY_COUNT/$MAX_RETRIES)\"",
            "  sleep $RETRY_INTERVAL",
            "done",
            "",
            "echo '📋 Container logs (last 20 lines)...'",
            "docker logs --tail 20 $APP_NAME || true",
            "",
            "echo '🧹 Cleaning up old images...'",
            "docker image prune -f",
            "",
            "echo '🎉 Deployment completed successfully!'"
          ]
        }
      }
    ]
  })
}


# Policy for GitHub Actions
resource "aws_iam_role_policy" "github_actions_policy" {
  name = "${var.project_name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeAddresses"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:document/${module.ssm.ssm_document_name}",
          module.ec2_instance.instance_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetCommandInvocation"
        ]
        Resource = "*"
      }
    ]
  })
}
