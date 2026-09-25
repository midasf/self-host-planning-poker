resource "aws_codestarconnections_connection" "github" {
  name          = "${var.repository_name}-github"
  provider_type = "GitHub"
  tags          = var.tags
}
