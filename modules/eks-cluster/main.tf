locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "eks-cluster"
  })
}

# KMS key for EKS cluster encryption
resource "aws_kms_key" "cluster" {
  count = var.cluster_encryption_config_enabled && var.cluster_encryption_config_kms_key_id == "" ? 1 : 0

  description             = "EKS cluster ${var.cluster_name} encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-cluster-encryption-key"
  })
}

resource "aws_kms_alias" "cluster" {
  count = var.cluster_encryption_config_enabled && var.cluster_encryption_config_kms_key_id == "" ? 1 : 0

  name          = "alias/${var.cluster_name}-cluster-encryption-key"
  target_key_id = aws_kms_key.cluster[0].key_id
}

# CloudWatch Log Group for EKS cluster
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_in_days

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-cluster-logs"
  })
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_service_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access_cidrs
    security_group_ids      = var.cluster_security_group_ids
  }

  dynamic "encryption_config" {
    for_each = var.cluster_encryption_config_enabled ? [1] : []
    content {
      provider {
        key_arn = var.cluster_encryption_config_kms_key_id != "" ? var.cluster_encryption_config_kms_key_id : aws_kms_key.cluster[0].arn
      }
      resources = var.cluster_encryption_config_resources
    }
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  depends_on = [
    aws_cloudwatch_log_group.cluster
  ]

  tags = merge(local.common_tags, {
    Name = var.cluster_name
  })
}

# OIDC Identity Provider
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-oidc-provider"
  })
}

# EKS Cluster additional security group
resource "aws_security_group" "cluster_additional" {
  name_prefix = "${var.cluster_name}-cluster-additional-"
  vpc_id      = var.vpc_id
  description = "Additional security group for EKS cluster"

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-cluster-additional-sg"
    Type = "cluster-additional"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Allow cluster to communicate with node groups
resource "aws_security_group_rule" "cluster_additional_ingress_nodes" {
  description              = "Allow nodes to communicate with cluster"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.cluster_additional.id
  security_group_id        = aws_security_group.cluster_additional.id
}

resource "aws_security_group_rule" "cluster_additional_egress_all" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster_additional.id
}

# EKS Cluster addon for CoreDNS
resource "aws_eks_addon" "coredns" {
  cluster_name      = aws_eks_cluster.main.name
  addon_name        = "coredns"
  addon_version     = data.aws_eks_addon_version.coredns.version
  resolve_conflicts = "OVERWRITE"

  depends_on = [aws_eks_cluster.main]

  tags = local.common_tags
}

# EKS Cluster addon for kube-proxy
resource "aws_eks_addon" "kube_proxy" {
  cluster_name      = aws_eks_cluster.main.name
  addon_name        = "kube-proxy"
  addon_version     = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts = "OVERWRITE"

  depends_on = [aws_eks_cluster.main]

  tags = local.common_tags
}

# EKS Cluster addon for VPC CNI
resource "aws_eks_addon" "vpc_cni" {
  cluster_name      = aws_eks_cluster.main.name
  addon_name        = "vpc-cni"
  addon_version     = data.aws_eks_addon_version.vpc_cni.version
  resolve_conflicts = "OVERWRITE"

  depends_on = [aws_eks_cluster.main]

  tags = local.common_tags
}

# Data sources for addon versions
data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}
