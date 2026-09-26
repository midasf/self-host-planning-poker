output "http_api_url" {
  description = "Base URL for the create endpoint, fronted by CloudFront (POST {url}/create)"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "websocket_url" {
  description = "WebSocket endpoint (CloudFront-fronted) the Angular client connects to"
  value       = "wss://${aws_cloudfront_distribution.this.domain_name}/prod"
}

output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "site_url" {
  description = "Public URL of the front-end (CloudFront)"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}
