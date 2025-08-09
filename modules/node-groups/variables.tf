variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  type        = string
}

variable "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  type        = string
}

variable "node_group_role_arn" {
  description = "ARN of the IAM role for the EKS node group"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS node groups"
  type        = list(string)
}

variable "node_security_group_ids" {
  description = "List of security group IDs for the EKS node groups"
  type        = list(string)
  default     = []
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
  default = {}
}

variable "default_instance_types" {
  description = "Default instance types for node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "default_ami_type" {
  description = "Default AMI type for node groups"
  type        = string
  default     = "AL2_x86_64"
}

variable "default_capacity_type" {
  description = "Default capacity type for node groups"
  type        = string
  default     = "ON_DEMAND"
}

variable "default_disk_size" {
  description = "Default disk size for node groups"
  type        = number
  default     = 20
}

variable "enable_bootstrap_user_data" {
  description = "Whether to enable bootstrap user data"
  type        = bool
  default     = false
}

variable "bootstrap_extra_args" {
  description = "Additional arguments for the bootstrap script"
  type        = string
  default     = ""
}

variable "pre_bootstrap_user_data" {
  description = "User data that is injected into the user data script ahead of the EKS bootstrap script"
  type        = string
  default     = ""
}

variable "post_bootstrap_user_data" {
  description = "User data that is appended to the user data script after of the EKS bootstrap script"
  type        = string
  default     = ""
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
