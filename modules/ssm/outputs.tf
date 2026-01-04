output "ssm_document_name" {
  description = "Name of the SSM document for deployment"
  value       = aws_ssm_document.deploy_app.name
}
