variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "ingredients-recognition-app"
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  default     = "renardelyon/rekognition-lambda"
}
