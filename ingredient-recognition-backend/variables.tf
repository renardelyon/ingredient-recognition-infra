variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "ingredients-recognition-app"
}

variable "service_name" {
  default = "ingredients_recognition_backend"
}

variable "app_port" {
  default = 8080
}

variable "container_port" {
  default = 8080
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  default     = "renardelyon/ingredient-recognition-backend"
}

# Nginx + Let's Encrypt Configuration
variable "enable_nginx_ssl" {
  description = "Enable Nginx with Let's Encrypt SSL"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Domain name for Let's Encrypt certificate (e.g., yourapp.duckdns.org)"
  type        = string
  default     = "https://recipe-recommendation-renard-elyon.duckdns.org"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
  default     = "renard.elyon.r@gmail.com"
}

