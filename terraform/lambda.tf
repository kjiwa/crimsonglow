# -- Alps (Migadu's webmail) runs as a plain HTTP server behind the Lambda Web Adapter.
# -- CI replaces the code on every push to main, so Terraform owns only the placeholder.

locals {
  webmail_host = "mail.${var.domain}"
  webmail_port = 1323
  login_key    = replace(replace(random_bytes.login_key.base64, "+", "-"), "/", "_")
}

# -- Alps wants a Fernet key: 32 random bytes in URL-safe base64.
resource "random_bytes" "login_key" {
  length = 32
}

data "archive_file" "webmail_placeholder" {
  type        = "zip"
  output_path = "${path.module}/.terraform/webmail-placeholder.zip"

  source {
    filename = "run.sh"
    content  = "#!/bin/sh\nexit 1\n"
  }
}

resource "aws_cloudwatch_log_group" "webmail" {
  name              = "/aws/lambda/webmail"
  retention_in_days = 30
}

resource "aws_lambda_function" "this" {
  function_name = "webmail"
  role          = aws_iam_role.webmail.arn
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  handler       = "run.sh"
  memory_size   = 512
  timeout       = 29

  filename         = data.archive_file.webmail_placeholder.output_path
  source_code_hash = data.archive_file.webmail_placeholder.output_base64sha256

  layers = ["arn:aws:lambda:${data.aws_region.default.region}:753240598075:layer:LambdaAdapterLayerArm64:30"]

  environment {
    variables = {
      AWS_LAMBDA_EXEC_WRAPPER    = "/opt/bootstrap"
      AWS_LWA_PORT               = local.webmail_port
      AWS_LWA_ENABLE_COMPRESSION = "true"
      ALPS_CONFIG = templatefile("${path.module}/webmail/alps.toml.tftpl", {
        host      = local.webmail_host
        port      = local.webmail_port
        login_key = local.login_key
      })
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.webmail.name
  }

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

resource "aws_lambda_permission" "webmail_api" {
  statement_id  = "AllowApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
