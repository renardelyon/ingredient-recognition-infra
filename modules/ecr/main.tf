terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.92"
    }
  }
}

resource "aws_ecr_repository" "ingredients_recognition_backend" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.app_name
  }

}

resource "aws_ecr_lifecycle_policy" "ingredients_recognition_backend_policy" {
  repository = aws_ecr_repository.ingredients_recognition_backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = var.lifecycle_policy.description
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.lifecycle_policy.quantity
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

