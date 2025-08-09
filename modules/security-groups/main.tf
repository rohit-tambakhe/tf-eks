locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "eks-security"
  })
}

# EKS Cluster Security Group
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-"
  vpc_id      = var.vpc_id
  description = "Security group for EKS cluster control plane"

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-cluster-sg"
    Type = "cluster"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Cluster security group rules
resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  count = var.enable_cluster_api_access && length(var.cluster_api_access_cidrs) > 0 ? 1 : 0

  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.cluster_api_access_cidrs
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "cluster_ingress_nodes" {
  description              = "Allow nodes to communicate with cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id        = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "cluster_egress_all" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
}

# EKS Node Group Security Group
resource "aws_security_group" "node_group" {
  name_prefix = "${var.cluster_name}-node-group-"
  vpc_id      = var.vpc_id
  description = "Security group for EKS node groups"

  tags = merge(local.common_tags, {
    Name                                        = "${var.cluster_name}-node-group-sg"
    Type                                        = "node-group"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Node group security group rules
resource "aws_security_group_rule" "node_group_ingress_self" {
  description              = "Allow nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id        = aws_security_group.node_group.id
}

resource "aws_security_group_rule" "node_group_ingress_cluster_https" {
  description              = "Allow cluster control plane to communicate with nodes"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node_group.id
}

resource "aws_security_group_rule" "node_group_ingress_cluster_kubelet" {
  description              = "Allow cluster control plane to communicate with kubelet"
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node_group.id
}

resource "aws_security_group_rule" "node_group_ingress_cluster_coredns_tcp" {
  description              = "Allow cluster control plane to communicate with CoreDNS"
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node_group.id
}

resource "aws_security_group_rule" "node_group_ingress_cluster_coredns_udp" {
  description              = "Allow cluster control plane to communicate with CoreDNS"
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node_group.id
}

resource "aws_security_group_rule" "node_group_ingress_alb" {
  description              = "Allow ALB to communicate with node groups"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.node_group.id
}

resource "aws_security_group_rule" "node_group_egress_all" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node_group.id
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.cluster_name}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-alb-sg"
    Type = "alb"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ALB security group rules
resource "aws_security_group_rule" "alb_ingress_http" {
  description       = "Allow HTTP traffic from internet"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_https" {
  description       = "Allow HTTPS traffic from internet"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_custom" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  description       = "Allow custom traffic from specified CIDR blocks"
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress_all" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# RDS Security Group (optional, for database workloads)
resource "aws_security_group" "rds" {
  name_prefix = "${var.cluster_name}-rds-"
  vpc_id      = var.vpc_id
  description = "Security group for RDS instances"

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-rds-sg"
    Type = "rds"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# RDS security group rules
resource "aws_security_group_rule" "rds_ingress_mysql" {
  description              = "Allow MySQL/Aurora access from node groups"
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id        = aws_security_group.rds.id
}

resource "aws_security_group_rule" "rds_ingress_postgres" {
  description              = "Allow PostgreSQL access from node groups"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id        = aws_security_group.rds.id
}

resource "aws_security_group_rule" "rds_egress_all" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
}

# Additional Security Group for EFS (if needed)
resource "aws_security_group" "efs" {
  name_prefix = "${var.cluster_name}-efs-"
  vpc_id      = var.vpc_id
  description = "Security group for EFS mount targets"

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-efs-sg"
    Type = "efs"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# EFS security group rules
resource "aws_security_group_rule" "efs_ingress_nfs" {
  description              = "Allow NFS access from node groups"
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id        = aws_security_group.efs.id
}

resource "aws_security_group_rule" "efs_egress_all" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.efs.id
}
