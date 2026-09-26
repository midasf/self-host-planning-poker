# WebSocket API for real-time play. The action in the message body selects the
# route (see aws/src/handlers/ws.py).
resource "aws_apigatewayv2_api" "websocket" {
  name                       = "${var.project_name}-websocket"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"

  tags = var.tags
}

resource "aws_apigatewayv2_integration" "ws_connect" {
  api_id           = aws_apigatewayv2_api.websocket.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.fn["ws_connect"].invoke_arn
}

resource "aws_apigatewayv2_integration" "ws_disconnect" {
  api_id           = aws_apigatewayv2_api.websocket.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.fn["ws_disconnect"].invoke_arn
}

resource "aws_apigatewayv2_integration" "ws_default" {
  api_id           = aws_apigatewayv2_api.websocket.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.fn["ws_default"].invoke_arn
}

resource "aws_apigatewayv2_route" "ws_connect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.ws_connect.id}"
}

resource "aws_apigatewayv2_route" "ws_disconnect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.ws_disconnect.id}"
}

resource "aws_apigatewayv2_route" "ws_default" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.ws_default.id}"
}

resource "aws_apigatewayv2_stage" "websocket" {
  # Access logging needs the account-level CloudWatch Logs role to exist first.
  depends_on = [aws_api_gateway_account.this]

  api_id      = aws_apigatewayv2_api.websocket.id
  name        = "prod"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 50
    throttling_rate_limit  = 25
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.websocket_api.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      connectionId     = "$context.connectionId"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "websocket_api" {
  name              = "/aws/apigateway/${var.project_name}-websocket"
  retention_in_days = 14
  tags              = var.tags
}
