# -- CloudFront cannot front this: OAC on a Lambda origin needs the viewer to send a body
# -- hash on POST, which a browser cannot. The execute-api endpoint is disabled so the
# -- custom domain is the only way in.
resource "aws_apigatewayv2_api" "this" {
  name                         = "webmail"
  protocol_type                = "HTTP"
  disable_execute_api_endpoint = true
}

resource "aws_apigatewayv2_integration" "this" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "this" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.this.id}"
}

# -- Alps counts rate limits per Lambda environment, so the stage caps total load.
resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
  }
}

resource "aws_apigatewayv2_domain_name" "this" {
  domain_name = local.webmail_host

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.webmail.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
    ip_address_type = "dualstack"
  }
}

resource "aws_apigatewayv2_api_mapping" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  domain_name = aws_apigatewayv2_domain_name.this.id
  stage       = aws_apigatewayv2_stage.this.id
}
