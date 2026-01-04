resource "aws_ssm_document" "deploy_app" {
  name            = "${var.project_name}-deploy"
  document_type   = "Command"
  document_format = "YAML"

  content = var.content
  tags = {
    Name = "${var.project_name}-deploy-document"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = var.ssm_attached_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
