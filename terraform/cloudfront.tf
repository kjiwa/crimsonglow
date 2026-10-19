data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "crimsonglow-site"
  description                       = "Signs CloudFront requests to the site bucket."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "this" {
  name    = "crimsonglow-router"
  comment = "Apex host, lobby redirect, legacy redirects, and directory index."
  runtime = "cloudfront-js-2.0"
  publish = true
  code = templatefile("${path.module}/functions/router.js.tftpl", {
    domain    = var.domain
    home      = local.home
    redirects = jsonencode(local.redirects)
  })
}

resource "aws_cloudfront_response_headers_policy" "this" {
  name = "crimsonglow-security-headers"

  security_headers_config {
    # -- No includeSubDomains: subdomains such as mail do not all serve valid HTTPS.
    # -- No preload either, which requires includeSubDomains.
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = false
      preload                    = false
      override                   = true
    }

    content_type_options {
      override = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    frame_options {
      frame_option = "SAMEORIGIN"
      override     = true
    }

    # -- style-src unsafe-inline is deliberate: every page carries its stylesheet
    # -- inline. frame-src covers the Slides embed in the 2016 job-search post.
    content_security_policy {
      content_security_policy = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self'; frame-src https://docs.google.com; frame-ancestors 'self'; base-uri 'none'; form-action 'none'; object-src 'none'; connect-src 'none'; require-trusted-types-for 'script'"
      override                = true
    }
  }

  custom_headers_config {
    items {
      header   = "Cross-Origin-Opener-Policy"
      value    = "same-origin"
      override = true
    }

    items {
      header   = "Permissions-Policy"
      value    = "geolocation=(), camera=(), microphone=(), payment=(), usb=()"
      override = true
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2and3"
  price_class     = "PriceClass_100"
  comment         = var.domain

  origin {
    origin_id                = "site"
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id           = "site"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.this.arn
    }
  }

  # -- A missing key returns 403 through OAC without s3:ListBucket.
  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "${local.home}/404.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "${local.home}/404.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
