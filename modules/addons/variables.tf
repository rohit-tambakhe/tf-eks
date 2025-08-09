variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
}

variable "enable_ebs_csi_driver" {
  description = "Whether to enable EBS CSI driver addon"
  type        = bool
  default     = true
}

variable "ebs_csi_driver_service_account_role_arn" {
  description = "ARN of the IAM role for EBS CSI driver service account"
  type        = string
  default     = ""
}

variable "enable_aws_load_balancer_controller" {
  description = "Whether to enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_service_account_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller service account"
  type        = string
  default     = ""
}

variable "enable_cluster_autoscaler" {
  description = "Whether to enable Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_service_account_role_arn" {
  description = "ARN of the IAM role for Cluster Autoscaler service account"
  type        = string
  default     = ""
}

variable "enable_metrics_server" {
  description = "Whether to enable Metrics Server"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Whether to enable External DNS"
  type        = bool
  default     = false
}

variable "external_dns_service_account_role_arn" {
  description = "ARN of the IAM role for External DNS service account"
  type        = string
  default     = ""
}

variable "external_dns_domain_filters" {
  description = "List of domains to filter for External DNS"
  type        = list(string)
  default     = []
}

variable "enable_efs_csi_driver" {
  description = "Whether to enable EFS CSI driver"
  type        = bool
  default     = false
}

variable "efs_csi_driver_service_account_role_arn" {
  description = "ARN of the IAM role for EFS CSI driver service account"
  type        = string
  default     = ""
}

variable "enable_cert_manager" {
  description = "Whether to enable cert-manager"
  type        = bool
  default     = false
}

variable "cert_manager_email" {
  description = "Email for cert-manager ACME registration"
  type        = string
  default     = ""
}

variable "enable_ingress_nginx" {
  description = "Whether to enable NGINX Ingress Controller"
  type        = bool
  default     = false
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
