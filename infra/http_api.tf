# HTTP API for creating games (POST /create).
resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project_name}-http"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
    max_age       = 300
  }

  tags = var.tags
}

resource "aws_apigatewayv2_integration" "create" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.fn["create"].invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "create" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /create"
  target    = "integrations/${aws_apigatewayv2_integration.create.id}"
}

resource "aws_apigatewayv2_stage" "http" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.http_api.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "http_api" {
  name              = "/aws/apigateway/${var.project_name}-http"
  retention_in_days = 14
  tags              = var.tags
}
