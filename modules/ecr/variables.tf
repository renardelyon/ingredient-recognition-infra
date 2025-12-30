variable "app_name" {
  description = "application name"
  nullable    = false
  type        = string
}

variable "lifecycle_policy" {
  description = "ECR lifecycle policy description"
  type = object({
    description = string
    quantity    = number
  })
  nullable = false
}
