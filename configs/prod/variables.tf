variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-prod"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.2.10.0/24", "10.2.20.0/24", "10.2.30.0/24"]
}

variable "node_groups" {
  description = "Map of EKS node group configurations"
  type = map(object({
    instance_types        = list(string)
    ami_type             = string
    capacity_type        = string
    disk_size            = number
    desired_size         = number
    max_size             = number
    min_size             = number
    max_unavailable      = number
    labels               = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
    tags = map(string)
  }))
  default = {
    system = {
      instance_types   = ["m5.xlarge"]
      ami_type        = "AL2_x86_64"
      capacity_type   = "ON_DEMAND"
      disk_size       = 50
      desired_size    = 3
      max_size        = 6
      min_size        = 3
      max_unavailable = 1
      labels = {
        role = "system"
      }
      taints = []
      tags = {
        Environment = "prod"
        NodeGroup   = "system"
      }
    }
    application = {
      instance_types   = ["m5.large"]
      ami_type        = "AL2_x86_64"
      capacity_type   = "ON_DEMAND"
      disk_size       = 50
      desired_size    = 5
      max_size        = 10
      min_size        = 3
      max_unavailable = 2
      labels = {
        role = "application"
      }
      taints = []
      tags = {
        Environment = "prod"
        NodeGroup   = "application"
      }
    }
    compute = {
      instance_types   = ["c5.xlarge"]
      ami_type        = "AL2_x86_64"
      capacity_type   = "ON_DEMAND"
      disk_size       = 100
      desired_size    = 2
      max_size        = 8
      min_size        = 2
      max_unavailable = 1
      labels = {
        role = "compute"
      }
      taints = []
      tags = {
        Environment = "prod"
        NodeGroup   = "compute"
      }
    }
  }
}

variable "enable_cluster_autoscaler" {
  description = "Whether to enable cluster autoscaler"
  type        = bool
  default     = true
}

variable "enable_aws_load_balancer_controller" {
  description = "Whether to enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_ebs_csi_driver" {
  description = "Whether to enable EBS CSI driver"
  type        = bool
  default     = true
}

variable "enable_efs_csi_driver" {
  description = "Whether to enable EFS CSI driver"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Whether to enable Metrics Server"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Whether to enable External DNS"
  type        = bool
  default     = true
}

variable "enable_cert_manager" {
  description = "Whether to enable cert-manager"
  type        = bool
  default     = true
}

variable "enable_ingress_nginx" {
  description = "Whether to enable NGINX Ingress Controller"
  type        = bool
  default     = true
}

variable "enable_container_insights" {
  description = "Whether to enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "enable_fluent_bit" {
  description = "Whether to enable AWS for Fluent Bit"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Whether to enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "enable_prometheus" {
  description = "Whether to enable Prometheus monitoring"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Whether to enable Grafana dashboards"
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
  default     = 30
}

variable "endpoint_private_access" {
  description = "Whether the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = []
}

variable "single_nat_gateway" {
  description = "Should be true to provision a single shared NAT Gateway across all private networks"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    Environment = "prod"
    Project     = "eks-infrastructure"
    ManagedBy   = "terraform"
  }
}
