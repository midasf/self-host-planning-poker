# Reuse the Python backend in aws/src as the Lambda code. It has no third-party
# dependencies (boto3 is provided by the runtime), so no vendoring is needed.
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../aws/src"
  output_path = "${path.module}/../aws/lambda.zip"
}

locals {
  functions = {
    create        = "handlers/create.handler"
    ws_connect    = "handlers/ws.connect_handler"
    ws_disconnect = "handlers/ws.disconnect_handler"
    ws_default    = "handlers/ws.default_handler"
  }
  ws_functions = { for k, v in local.functions : k => v if startswith(k, "ws_") }
}

resource "aws_lambda_function" "fn" {
  for_each = local.functions

  function_name    = "${var.project_name}-${each.key}"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = each.value
  runtime          = "python3.12"
  timeout          = 15
  memory_size      = 256
  architectures    = ["arm64"]

  # Cap concurrency on the write/cost-heavy functions to bound the blast radius
  # of a request flood. Only create + ws_default reserve (keeps the total draw on
  # the account's concurrency pool small); set the var to -1 to disable entirely
  # on accounts with a low concurrency limit.
  reserved_concurrent_executions = (
    var.lambda_reserved_concurrency >= 0 && contains(["create", "ws_default"], each.key)
    ? var.lambda_reserved_concurrency
    : null
  )

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.games.name
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = local.functions

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = 14
  tags              = var.tags
}

# HTTP API may invoke the create function.
resource "aws_lambda_permission" "http_create" {
  statement_id  = "AllowHttpApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn["create"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

# WebSocket API may invoke the connect/disconnect/default functions.
resource "aws_lambda_permission" "ws" {
  for_each = local.ws_functions

  statement_id  = "AllowWebSocketInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket.execution_arn}/*/*"
}
