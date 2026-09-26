# Shared secret injected by CloudFront as the X-Origin-Verify header on every
# request it forwards to the HTTP and WebSocket APIs. The create and $connect
# Lambdas reject requests missing it, so the execute-api URLs can't be used
# directly (all traffic must go through CloudFront + WAF).
resource "random_password" "origin_secret" {
  length  = 40
  special = false
}
