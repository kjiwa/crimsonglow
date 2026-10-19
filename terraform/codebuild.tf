resource "aws_codebuild_project" "mail_backup" {
  name          = local.mail_backup_name
  description   = "Nightly one-way pull of each Migadu mailbox into the archive bucket."
  service_role  = aws_iam_role.mail_backup.arn
  build_timeout = 30

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    type         = "LINUX_CONTAINER"
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:8.0"
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.mail_backup.name
    }
  }

  source {
    type = "NO_SOURCE"
    buildspec = yamlencode({
      version = 0.2
      phases = {
        build = {
          commands = concat(
            [
              "apt-get update -qq",
              "apt-get install -y -qq isync",
              "aws s3 cp s3://${aws_s3_bucket.archive.id}/${aws_s3_object.mbsyncrc.key} \"$HOME/.mbsyncrc\"",
            ],
            flatten([for address in keys(var.mailboxes) : [
              "mkdir -p \"$HOME/crimsonglow-mail/${address}\"",
              "aws s3 sync --only-show-errors s3://${aws_s3_bucket.archive.id}/migadu/${address} \"$HOME/crimsonglow-mail/${address}\"",
              # -- S3 holds no empty directories, so a mailbox with no messages loses cur/new/tmp.
              "find \"$HOME/crimsonglow-mail/${address}\" -name .uidvalidity -execdir mkdir -p cur new tmp \\;",
              "mbsync backup-${address}",
              # -- Sync state lives in the Maildir, so it round-trips through S3 with the mail.
              "aws s3 sync --only-show-errors --delete \"$HOME/crimsonglow-mail/${address}\" s3://${aws_s3_bucket.archive.id}/migadu/${address}",
            ]])
          )
        }
      }
    })
  }
}
