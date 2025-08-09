variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "enable_container_insights" {
  description = "Whether to enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "enable_fluent_bit" {
  description = "Whether to enable AWS for Fluent Bit for log aggregation"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Whether to enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "alarm_notification_emails" {
  description = "List of email addresses to notify for alarms"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
}

variable "enable_prometheus" {
  description = "Whether to enable Prometheus monitoring"
  type        = bool
  default     = false
}

variable "enable_grafana" {
  description = "Whether to enable Grafana dashboards"
  type        = bool
  default     = false
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  default     = ""
  sensitive   = true
}

variable "prometheus_storage_size" {
  description = "Storage size for Prometheus"
  type        = string
  default     = "50Gi"
}

variable "grafana_storage_size" {
  description = "Storage size for Grafana"
  type        = string
  default     = "10Gi"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
