resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "github_deploy" {
  name = "github-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_deploy" {
  name = "deploy-site"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.this.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.this.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "cloudfront:CreateInvalidation"
        Resource = aws_cloudfront_distribution.this.arn
      }
    ]
  })
}

check "deploy_role_trust_has_no_wildcard_principal" {
  assert {
    condition     = !strcontains(aws_iam_role.github_deploy.assume_role_policy, "\"*\"")
    error_message = "The deploy role's trust policy must not use a wildcard principal."
  }
}

# -- mail backup: CodeBuild writes the archive's migadu/ prefix; Scheduler starts the build.

data "aws_kms_alias" "ssm" {
  name = "alias/aws/ssm"
}

data "aws_iam_policy_document" "mail_backup_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mail_backup" {
  name               = "mail-backup"
  assume_role_policy = data.aws_iam_policy_document.mail_backup_trust.json
}

# -- No s3:DeleteObjectVersion: `sync --delete` leaves delete markers, so history survives a bad run.
resource "aws_iam_role_policy" "mail_backup" {
  name = "backup-mail"
  role = aws_iam_role.mail_backup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.archive.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.archive.arn}/migadu/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.archive.arn}/${aws_s3_object.mbsyncrc.key}"
      },
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = "arn:aws:ssm:${data.aws_region.default.region}:${var.account_id}:parameter/mail/*"
      },
      {
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = data.aws_kms_alias.ssm.target_key_arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.mail_backup.arn}:*"
      }
    ]
  })
}

data "aws_iam_policy_document" "mail_backup_scheduler_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mail_backup_scheduler" {
  name               = "mail-backup-scheduler"
  assume_role_policy = data.aws_iam_policy_document.mail_backup_scheduler_trust.json
}

resource "aws_iam_role_policy" "mail_backup_scheduler" {
  name = "start-mail-backup"
  role = aws_iam_role.mail_backup_scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "codebuild:StartBuild"
        Resource = aws_codebuild_project.mail_backup.arn
      }
    ]
  })
}
