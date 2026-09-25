locals {
  frontend_origin_id = "s3-frontend"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  comment             = var.project_name
  web_acl_id          = aws_wafv2_web_acl.this.arn

  origin {
    origin_id                = local.frontend_origin_id
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # SPA: everything is served from S3; the HTTP/WebSocket APIs are hit directly.
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

    # The SPA talks to the HTTP API (https) and WebSocket API (wss) directly.
    content_security_policy {
      content_security_policy = "default-src 'self'; img-src 'self' data:; connect-src 'self' https://*.execute-api.${var.aws_region}.amazonaws.com wss://*.execute-api.${var.aws_region}.amazonaws.com; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
      override                = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}
