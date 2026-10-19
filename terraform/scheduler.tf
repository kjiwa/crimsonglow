resource "aws_scheduler_schedule" "mail_backup" {
  name                = local.mail_backup_name
  schedule_expression = "rate(1 day)"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:codebuild:startBuild"
    role_arn = aws_iam_role.mail_backup_scheduler.arn
    input    = jsonencode({ ProjectName = aws_codebuild_project.mail_backup.name })
  }
}
