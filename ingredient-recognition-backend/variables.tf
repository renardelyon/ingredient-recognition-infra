variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "ingredients-recognition-app"
}

variable "app_port" {
  default = 443
}

variable "container_port" {
  default = 8080
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  default     = "renardelyon/rekognition-lambda"
}

