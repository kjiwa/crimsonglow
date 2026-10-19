# -- Migadu offers no custom webmail hostname, so mail.<domain> only redirects.
# -- The function answers every request, so the origin is never contacted; it is
# -- the site bucket only because a distribution requires one.

resource "aws_acm_certificate" "webmail" {
  provider = aws.us_east_1

  domain_name       = "mail.${var.domain}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "webmail_validation" {
  for_each = {
    for o in aws_acm_certificate.webmail.domain_validation_options : o.domain_name => o
  }

  zone_id         = aws_route53_zone.this.zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "webmail" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.webmail.arn
  validation_record_fqdns = [for r in aws_route53_record.webmail_validation : r.fqdn]
}

resource "aws_cloudfront_function" "webmail" {
  name    = "crimsonglow-webmail"
  comment = "Redirects mail.${var.domain} to the webmail URL."
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = templatefile("${path.module}/functions/webmail.js.tftpl", { webmail_url = var.webmail_url })
}

resource "aws_cloudfront_distribution" "webmail" {
  aliases         = ["mail.${var.domain}"]
  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2and3"
  price_class     = "PriceClass_100"
  comment         = "mail.${var.domain}"

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
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.webmail.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.webmail.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
