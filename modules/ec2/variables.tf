variable "aws_region" {
  default = "us-east-1"
}

variable "ami_type" {
  description = "The type of image want to use in ec2"
  type        = set(string)
  nullable    = false
}

variable "app_name" {
  description = "The project application name"
  type        = string
  nullable    = false
}

variable "aws_security_group_var" {
  description = "Variable to create security group rules"
  type = object({
    vpc_id         = string
    ssh_allowed_ip = string
    app_port       = number
  })
  nullable = false
}

variable "aws_dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  type        = string
  nullable    = false
}


variable "keypair_creation_config" {
  description = "Configuration for keypair creation"
  type = object({
    create_key_pair = bool
    public_key      = string
  })
  nullable = true
}

variable "aws_caller_identity_account_id" {
  description = "AWS Account ID"
  type        = string
  nullable    = false
}

variable "app_port" {
  description = "application port"
  type        = number
  nullable    = false
}
variable "container_port" {
  description = "container port"
  type        = number
  nullable    = false
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  nullable    = true
}

variable "use_elastic_ip" {
  description = "Whether to associate an Elastic IP with the EC2 instance"
  type        = bool
  nullable    = true
  default     = false
}

variable "subnet_id" {
  description = "The subnet ID to launch the EC2 instance in"
  type        = string
  nullable    = false
}

variable "instance_state" {
  description = "The state of EC2 Instance"
  type        = string
  default     = "running"
}

variable "enable_nginx_ssl" {
  description = "Enable Nginx with Let's Encrypt SSL"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name for Let's Encrypt certificate"
  type        = string
  default     = null
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate"
  type        = string
  default     = null
}
