provider "aws" {
  region = var.aws_region
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
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

  app_name = "ingredients_recognition_backend"
  lifecycle_policy = {
    description = "Keep last 10 images"
    quantity    = 10
  }
}

module "dynamodb" {
  source = "../modules/dynamodb"

  create_dynamodb_config = {
    billing_mode = "PAY_PER_REQUEST"
    enable_pitr  = false
    hash_key     = "id"
    range_key    = "created_at"
    table_name   = "Users"
    global_secondary_indexes = [
      {
        name     = "email"
        hash_key = "EmailIndex"
        type     = "S"
    }]
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
  aws_dynamodb_table_arn         = module.dynamodb.aws_dynamodb_table_arn
  use_elastic_ip                 = true
  instance_type                  = "t3.micro"
  subnet_id                      = data.aws_subnets.default.ids[0]
  keypair_creation_config = {
    create_key_pair = true
    public_key      = file("~/.ssh/id_ed25519.pub")
  }
}
