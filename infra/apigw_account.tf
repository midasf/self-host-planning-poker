# API Gateway WebSocket (v2) stage access logging requires an account-level
# CloudWatch Logs role (HTTP APIs don't, but WebSocket stages do). Without this,
# enabling access_log_settings on the WS stage fails with
# "CloudWatch Logs role ARN must be set in account settings to enable logging".
resource "aws_iam_role" "apigw_cloudwatch" {
  name = "${var.project_name}-apigw-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "apigw_cloudwatch" {
  role       = aws_iam_role.apigw_cloudwatch.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch.arn
}
