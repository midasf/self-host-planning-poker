locals {
  frontend_origin_id = "s3-frontend"
  http_origin_id     = "http-api"
  ws_origin_id       = "ws-api"
  http_api_host      = "${aws_apigatewayv2_api.http.id}.execute-api.${var.aws_region}.amazonaws.com"
  ws_api_host        = "${aws_apigatewayv2_api.websocket.id}.execute-api.${var.aws_region}.amazonaws.com"

  # AWS managed CloudFront policies.
  caching_disabled_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  all_viewer_except_host_request_policy = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
}

resource "aws_cloudfront_distribution" "this" {
  # Log delivery validates the bucket's ACL grants at create time.
  depends_on = [aws_s3_bucket_acl.logs]

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  comment             = var.project_name
  web_acl_id          = aws_wafv2_web_acl.this.arn

  logging_config {
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    prefix          = "cloudfront/"
    include_cookies = false
  }

  origin {
    origin_id                = local.frontend_origin_id
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # HTTP API (create). The secret header lets the Lambda reject requests that
  # skip CloudFront and hit the execute-api URL directly.
  origin {
    origin_id   = local.http_origin_id
    domain_name = local.http_api_host
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.origin_secret.result
    }
  }

  # WebSocket API. CloudFront proxies the WSS upgrade to the "prod" stage; the
  # viewer connects to wss://<cf-domain>/prod (no origin_path needed).
  origin {
    origin_id   = local.ws_origin_id
    domain_name = local.ws_api_host
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.origin_secret.result
    }
  }

  # POST /create -> HTTP API (no caching).
  ordered_cache_behavior {
    path_pattern               = "/create"
    target_origin_id           = local.http_origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = local.caching_disabled_policy_id
    origin_request_policy_id   = local.all_viewer_except_host_request_policy
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # wss://<cf-domain>/prod -> WebSocket API (glob so a trailing path/query still routes here).
  ordered_cache_behavior {
    path_pattern             = "/prod*"
    target_origin_id         = local.ws_origin_id
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = false
    cache_policy_id          = local.caching_disabled_policy_id
    origin_request_policy_id = local.all_viewer_except_host_request_policy
  }

  # SPA: everything else is served from the S3 frontend.
  default_cache_behavior {
    target_origin_id       = local.frontend_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 300
    max_ttl     = 3600

    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # Angular client-side routing: unknown keys (403 from the private bucket) and
  # 404s fall back to index.html.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name = "${var.project_name}-security-headers"

  security_headers_config {
    content_type_options { override = true }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    # Angular injects component styles as inline <style> tags at runtime, so
    # style-src needs 'unsafe-inline'. Scripts stay 'self' (AOT, no inline JS).
    # The HTTP + WebSocket APIs are now same-origin (fronted by CloudFront), so
    # connect-src is just 'self'.
    content_security_policy {
      content_security_policy = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
      override                = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}
