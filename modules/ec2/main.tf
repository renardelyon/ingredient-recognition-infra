terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.92"
    }
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = var.ami_type
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "ec2_security_group" {
  name        = "${var.app_name}-sg"
  description = "Security group for ${var.app_name} application"
  vpc_id      = var.aws_security_group_var.vpc_id

  tags = {
    "Name" = "${var.app_name}-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_access" {
  security_group_id = aws_security_group.ec2_security_group.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.aws_security_group_var.ssh_allowed_ip
}

resource "aws_vpc_security_group_ingress_rule" "http_access" {
  security_group_id = aws_security_group.ec2_security_group.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "app_access" {
  security_group_id = aws_security_group.ec2_security_group.id
  from_port         = var.aws_security_group_var.app_port
  to_port           = var.aws_security_group_var.app_port
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "outbound_access" {
  security_group_id = aws_security_group.ec2_security_group.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "${var.app_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.app_name}-ec2-role"
  }
}

# IAM Policy for ECR access
resource "aws_iam_role_policy" "ecr_access" {
  name = "${var.app_name}-ecr-policy"
  role = aws_iam_role.ec2_role.id

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

# IAM Policy for Bedrock and Rekognition
resource "aws_iam_role_policy" "bedrock_rekognition" {
  name = "${var.app_name}-bedrock-rekognition-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectLabels",
          "rekognition:DetectText",
          "rekognition:RecognizeCelebrities",
          "rekognition:DetectFaces"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for DynamoDB access
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.app_name}-dynamodb-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          var.aws_dynamodb_table_arn,
          "${var.aws_dynamodb_table_arn}/index/*"
        ]
      }
    ]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.app_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Key Pair (optional - create one if you don't have it)
resource "aws_key_pair" "deployer" {
  count      = var.keypair_creation_config.create_key_pair ? 1 : 0
  key_name   = "${var.app_name}-key"
  public_key = var.keypair_creation_config.public_key

  tags = {
    Name = "${var.app_name}-key"
  }
}

# User data script to setup the application
locals {
  ecr_url = "${var.aws_caller_identity_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    yum update -y
    
    # Install Docker
    yum install -y docker
    systemctl start docker
    systemctl enable docker

  EOF
}

# EC2 Instance
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.keypair_creation_config.create_key_pair ? aws_key_pair.deployer[0].key_name : ""
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  subnet_id              = var.subnet_id

  user_data = base64encode(local.user_data)

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.app_name}-instance"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IP (optional but recommended)
resource "aws_eip" "app" {
  count    = var.use_elastic_ip ? 1 : 0
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name = "${var.app_name}-eip"
  }
}

resource "aws_ec2_instance_state" "app_state" {
  instance_id = aws_instance.app.id
  state       = var.instance_state # Use "running" to start it again
}


resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# SSM Document for deployment
resource "aws_ssm_document" "deploy_app" {
  name            = "${var.app_name}-deploy"
  document_type   = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Deploy ${var.app_name} application"
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
      ServerPort = {
        type        = "String"
        default     = "8080"
        description = "Server port"
      }
      ServerAddress = {
        type        = "String"
        default     = ":8080"
        description = "Server address"
      }
      RekognitionProjectArn = {
        type        = "String"
        description = "Rekognition project ARN"
      }
      RekognitionModelVersion = {
        type        = "String"
        description = "Rekognition model version"
      }
      RekognitionMinConfidence = {
        type        = "String"
        default     = "0.5"
        description = "Rekognition minimum confidence"
      }
      JwtSecret = {
        type        = "String"
        description = "JWT secret"
      }
      JwtExpiryHours = {
        type        = "String"
        default     = "24"
        description = "JWT expiry hours"
      }
      BedrockModelId = {
        type        = "String"
        description = "Bedrock model ID"
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
            "SERVER_PORT='{{ServerPort}}'",
            "SERVER_ADDRESS='{{ServerAddress}}'",
            "REKOGNITION_PROJECT_ARN='{{RekognitionProjectArn}}'",
            "REKOGNITION_MODEL_VERSION='{{RekognitionModelVersion}}'",
            "REKOGNITION_MIN_CONFIDENCE='{{RekognitionMinConfidence}}'",
            "JWT_SECRET='{{JwtSecret}}'",
            "JWT_EXPIRY_HOURS='{{JwtExpiryHours}}'",
            "BEDROCK_MODEL_ID='{{BedrockModelId}}'",
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
            "  -p 8080:8080 \\",
            "  -e SERVER_PORT=\"$SERVER_PORT\" \\",
            "  -e SERVER_ADDRESS=\"$SERVER_ADDRESS\" \\",
            "  -e AWS_REGION=\"$AWS_REGION\" \\",
            "  -e REKOGNITION_PROJECT_ARN=\"$REKOGNITION_PROJECT_ARN\" \\",
            "  -e REKOGNITION_MODEL_VERSION=\"$REKOGNITION_MODEL_VERSION\" \\",
            "  -e REKOGNITION_MIN_CONFIDENCE=\"$REKOGNITION_MIN_CONFIDENCE\" \\",
            "  -e JWT_SECRET=\"$JWT_SECRET\" \\",
            "  -e JWT_EXPIRY_HOURS=\"$JWT_EXPIRY_HOURS\" \\",
            "  -e BEDROCK_MODEL_ID=\"$BEDROCK_MODEL_ID\" \\",
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
            "  if curl -sf http://localhost:8080/health > /dev/null 2>&1; then",
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

  tags = {
    Name = "${var.app_name}-deploy-document"
  }
}


