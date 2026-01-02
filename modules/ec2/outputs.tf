output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.app.id
}

output "instance_arn" {
  description = "The ARN of the EC2 instance"
  value       = aws_instance.app.arn
}

output "public_ip" {
  description = "The public IP of the EC2 instance"
  value       = var.use_elastic_ip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip
}

output "private_ip" {
  description = "The private IP of the EC2 instance"
  value       = aws_instance.app.private_ip
}

output "ssm_document_name" {
  description = "Name of the SSM document for deployment"
  value       = aws_ssm_document.deploy_app.name
}
