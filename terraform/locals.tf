locals {
  site_config = yamldecode(file("${path.module}/../site/_config.yml"))
  home        = local.site_config.home

  # -- CloudFront rejects a literal "~" in ResponsePagePath (InvalidArgument).
  error_page_path = "${replace(local.home, "~", "%7E")}/404.html"

  redirects = yamldecode(file("${path.module}/../site/_data/redirects.yml"))

  # Record keys are <fqdn>-<TYPE>; the fqdn may itself contain dashes.
  record_key_parts = { for k, r in var.records : k => split("-", k) }
  records = {
    for k, r in var.records : k => merge(r, {
      name = join("-", slice(local.record_key_parts[k], 0, length(local.record_key_parts[k]) - 1))
      type = element(local.record_key_parts[k], length(local.record_key_parts[k]) - 1)
    })
  }

  alias_targets = {
    site = {
      name    = aws_cloudfront_distribution.this.domain_name
      zone_id = aws_cloudfront_distribution.this.hosted_zone_id
    }
  }
}
