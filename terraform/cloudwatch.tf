data "aws_region" "default" {}

resource "aws_cloudwatch_log_group" "mail_backup" {
  name              = "/aws/codebuild/${local.mail_backup_name}"
  retention_in_days = 30
}

# -- Missing data breaches, so a job that stopped running alarms the same as one that fails.
resource "aws_cloudwatch_metric_alarm" "mail_backup" {
  alarm_name          = local.mail_backup_name
  alarm_description   = "No successful mail backup build in a day, two days running."
  namespace           = "AWS/CodeBuild"
  metric_name         = "SucceededBuilds"
  dimensions          = { ProjectName = aws_codebuild_project.mail_backup.name }
  statistic           = "Sum"
  period              = 86400
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.this.arn]
}
