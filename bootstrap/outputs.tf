output "codestar_connection_arn" {
  description = "Activate this connection in the AWS Console before the pipeline can pull from GitHub"
  value       = aws_codestarconnections_connection.github.arn
}

output "pipeline_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.this.name}/view"
}

output "state_bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}
