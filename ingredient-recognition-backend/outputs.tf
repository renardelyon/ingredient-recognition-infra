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
  value       = module.ec2_instance.ssm_document_name
}
