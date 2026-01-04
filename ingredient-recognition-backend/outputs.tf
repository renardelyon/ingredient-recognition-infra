output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.arn
}

output "ec2_instance_id" {
  description = "EC2 instance ID for SSM commands"
  value       = module.ec2_instance.instance_id
}

output "ssm_document_name" {
  description = "Name of the SSM document for deployment"
  value       = module.ssm.ssm_document_name
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = module.ec2_instance.public_ip
}

output "api_endpoint" {
  description = "API endpoint"
  value       = var.enable_nginx_ssl && var.domain_name != null ? "https://${var.domain_name}/api" : "http://${module.ec2_instance.public_ip}:${var.app_port}"
}
