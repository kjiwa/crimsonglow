data "archive_file" "webmail_placeholder" {
  type        = "zip"
  output_path = "${path.module}/.terraform/webmail-placeholder.zip"

  source {
    filename = "run.sh"
    content  = "#!/bin/sh\nexit 1\n"
  }
}
