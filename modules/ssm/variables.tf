variable "content" {
  description = "SSM document content in yaml"
  type        = string
  nullable    = false
}

variable "project_name" {
  description = "Project Name"
  type        = string
  nullable    = false
}

variable "ssm_attached_role_name" {
  description = "Role to attached to ssm"
  type        = string
  nullable    = false
}


