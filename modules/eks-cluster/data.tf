# Data source for current AWS caller identity
data "aws_caller_identity" "current" {}

# Data source for current AWS region
data "aws_region" "current" {}

# Data source for current AWS partition
data "aws_partition" "current" {}

# Data source for TLS certificate for OIDC thumbprint
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Data source for EKS cluster auth
data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}
