output "deploy_role_name" {
  description = "Set bootstrap/var.target_account_role to this to switch the pipeline off the admin role."
  value       = aws_iam_role.deploy.name
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}
