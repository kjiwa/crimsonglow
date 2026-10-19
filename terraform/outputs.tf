output "nameservers" {
  description = "Route 53 nameservers to set at the registrar."
  value       = aws_route53_zone.this.name_servers
}

output "site_bucket" {
  description = "Bucket the CI deploy job syncs the built site into."
  value       = aws_s3_bucket.this.id
}

output "distribution_id" {
  description = "CloudFront distribution ID, invalidated after each deploy."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_domain" {
  description = "CloudFront domain name, for probing before DNS points at it."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "deploy_role_arn" {
  description = "Role the GitHub deploy job assumes over OIDC."
  value       = aws_iam_role.github_deploy.arn
}
