output "cloudwatch_log_group_names" {
  description = "Names of CloudWatch log groups created"
  value = {
    application = aws_cloudwatch_log_group.application.name
    host        = aws_cloudwatch_log_group.host.name
    dataplane   = aws_cloudwatch_log_group.dataplane.name
  }
}

output "cloudwatch_log_group_arns" {
  description = "ARNs of CloudWatch log groups created"
  value = {
    application = aws_cloudwatch_log_group.application.arn
    host        = aws_cloudwatch_log_group.host.arn
    dataplane   = aws_cloudwatch_log_group.dataplane.arn
  }
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = var.enable_cloudwatch_alarms && length(var.alarm_notification_emails) > 0 ? aws_sns_topic.alerts[0].arn : null
}

output "cloudwatch_alarm_arns" {
  description = "ARNs of CloudWatch alarms created"
  value = var.enable_cloudwatch_alarms ? {
    cluster_failed_node_count = aws_cloudwatch_metric_alarm.cluster_failed_node_count[0].arn
    cluster_node_count_low    = aws_cloudwatch_metric_alarm.cluster_node_count[0].arn
    pod_cpu_utilization_high  = aws_cloudwatch_metric_alarm.pod_cpu_utilization[0].arn
    pod_memory_utilization_high = aws_cloudwatch_metric_alarm.pod_memory_utilization[0].arn
  } : {}
}

output "fluent_bit_role_arn" {
  description = "ARN of the Fluent Bit IAM role"
  value       = var.enable_fluent_bit ? aws_iam_role.fluent_bit[0].arn : null
}

output "prometheus_status" {
  description = "Status of the Prometheus Helm release"
  value       = var.enable_prometheus ? helm_release.prometheus[0].status : null
}

output "aws_for_fluent_bit_status" {
  description = "Status of the AWS for Fluent Bit Helm release"
  value       = var.enable_fluent_bit ? helm_release.aws_for_fluent_bit[0].status : null
}

output "monitoring_namespace" {
  description = "Name of the monitoring namespace"
  value       = var.enable_prometheus || var.enable_grafana ? kubernetes_namespace.monitoring[0].metadata[0].name : null
}
