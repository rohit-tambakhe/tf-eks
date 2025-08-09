locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "eks-monitoring"
  })
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# CloudWatch Log Groups for application logs
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/eks/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-application-logs"
  })
}

resource "aws_cloudwatch_log_group" "host" {
  name              = "/aws/eks/${var.cluster_name}/host"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-host-logs"
  })
}

resource "aws_cloudwatch_log_group" "dataplane" {
  name              = "/aws/eks/${var.cluster_name}/dataplane"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-dataplane-logs"
  })
}

# SNS Topic for alarm notifications
resource "aws_sns_topic" "alerts" {
  count = var.enable_cloudwatch_alarms && length(var.alarm_notification_emails) > 0 ? 1 : 0

  name = "${var.cluster_name}-eks-alerts"

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-eks-alerts"
  })
}

resource "aws_sns_topic_subscription" "email" {
  count = var.enable_cloudwatch_alarms && length(var.alarm_notification_emails) > 0 ? length(var.alarm_notification_emails) : 0

  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alarm_notification_emails[count.index]
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cluster_failed_node_count" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_name}-eks-failed-node-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "cluster_failed_node_count"
  namespace           = "ContainerInsights"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors eks failed node count"
  alarm_actions       = length(var.alarm_notification_emails) > 0 ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "cluster_node_count" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_name}-eks-node-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "cluster_node_count"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors eks node count"
  alarm_actions       = length(var.alarm_notification_emails) > 0 ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "pod_cpu_utilization" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_name}-eks-pod-cpu-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "pod_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors eks pod cpu utilization"
  alarm_actions       = length(var.alarm_notification_emails) > 0 ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "pod_memory_utilization" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_name}-eks-pod-memory-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "pod_memory_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors eks pod memory utilization"
  alarm_actions       = length(var.alarm_notification_emails) > 0 ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = local.common_tags
}

# IAM role for Fluent Bit
resource "aws_iam_role" "fluent_bit" {
  count = var.enable_fluent_bit ? 1 : 0

  name = "${var.cluster_name}-fluent-bit-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "fluent_bit" {
  count = var.enable_fluent_bit ? 1 : 0

  name        = "${var.cluster_name}-fluent-bit-policy"
  description = "IAM policy for Fluent Bit"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "fluent_bit" {
  count = var.enable_fluent_bit ? 1 : 0

  role       = aws_iam_role.fluent_bit[0].name
  policy_arn = aws_iam_policy.fluent_bit[0].arn
}

# Kubernetes resources for monitoring
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# CloudWatch Agent configuration
resource "kubernetes_config_map" "cloudwatch_config" {
  count = var.enable_container_insights ? 1 : 0

  metadata {
    name      = "cwagentconfig"
    namespace = "amazon-cloudwatch"
  }

  data = {
    "cwagentconfig.json" = jsonencode({
      logs = {
        metrics_collected = {
          kubernetes = {
            cluster_name = var.cluster_name
            metrics_collection_interval = 60
          }
        }
        force_flush_interval = 5
      }
    })
  }

  depends_on = [kubernetes_namespace.amazon_cloudwatch]
}

# Namespace for CloudWatch
resource "kubernetes_namespace" "amazon_cloudwatch" {
  count = var.enable_container_insights ? 1 : 0

  metadata {
    name = "amazon-cloudwatch"
    labels = {
      name = "amazon-cloudwatch"
    }
  }
}

# AWS for Fluent Bit
resource "helm_release" "aws_for_fluent_bit" {
  count = var.enable_fluent_bit ? 1 : 0

  name       = "aws-for-fluent-bit"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  namespace  = "kube-system"
  version    = "0.1.32"

  set {
    name  = "cloudWatchLogs.enabled"
    value = "true"
  }

  set {
    name  = "cloudWatchLogs.region"
    value = data.aws_region.current.name
  }

  set {
    name  = "cloudWatchLogs.logGroupName"
    value = "/aws/eks/${var.cluster_name}/application"
  }

  set {
    name  = "firehose.enabled"
    value = "false"
  }

  set {
    name  = "kinesis.enabled"
    value = "false"
  }

  set {
    name  = "elasticsearch.enabled"
    value = "false"
  }

  depends_on = [
    aws_cloudwatch_log_group.application
  ]
}

# Prometheus monitoring stack
resource "kubernetes_namespace" "monitoring" {
  count = var.enable_prometheus || var.enable_grafana ? 1 : 0

  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }
}

resource "helm_release" "prometheus" {
  count = var.enable_prometheus ? 1 : 0

  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = false
  version          = "51.2.0"

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          }
        }
      }
      grafana = {
        enabled = var.enable_grafana
        adminPassword = var.grafana_admin_password != "" ? var.grafana_admin_password : "admin"
        persistence = {
          enabled = true
          size = var.grafana_storage_size
        }
        service = {
          type = "LoadBalancer"
        }
      }
      alertmanager = {
        enabled = true
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring
  ]
}
