variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "ingredients_recognition_frontend"
}

variable "app_port" {
  default = 3000
}

variable "container_port" {
  default = 3000
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  default     = "renardelyon/ingredient-recognition-frontend"
}

# Nginx + Let's Encrypt Configuration
variable "enable_nginx_ssl" {
  description = "Enable Nginx with Let's Encrypt SSL"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name for Let's Encrypt certificate (e.g., frontend.yourapp.mooo.com)"
  type        = string
  default     = "frontend.recipe-recommendation-renard-elyon.mooo.com"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
  default     = "renard.elyon.r@gmail.com"
}
