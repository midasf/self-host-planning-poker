output "http_api_url" {
  description = "Base URL for the create endpoint (POST {url}/create)"
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "websocket_url" {
  description = "WebSocket endpoint the Angular client connects to"
  value       = aws_apigatewayv2_stage.websocket.invoke_url
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
