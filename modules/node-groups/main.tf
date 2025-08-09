locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "eks-node-groups"
  })

  # Merge default values with provided node group configurations
  node_groups = {
    for name, config in var.node_groups : name => {
      instance_types        = lookup(config, "instance_types", var.default_instance_types)
      ami_type             = lookup(config, "ami_type", var.default_ami_type)
      capacity_type        = lookup(config, "capacity_type", var.default_capacity_type)
      disk_size            = lookup(config, "disk_size", var.default_disk_size)
      desired_size         = config.desired_size
      max_size             = config.max_size
      min_size             = config.min_size
      max_unavailable      = lookup(config, "max_unavailable", 1)
      labels               = lookup(config, "labels", {})
      taints               = lookup(config, "taints", [])
      tags                 = lookup(config, "tags", {})
    }
  }
}

# Data source for the latest EKS optimized AMI
data "aws_ssm_parameter" "eks_ami_release_version" {
  for_each = local.node_groups

  name = "/aws/service/eks/optimized-ami/${data.aws_eks_cluster.cluster.version}/amazon-linux-2/recommended/release_version"
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# Launch template for each node group
resource "aws_launch_template" "node_group" {
  for_each = local.node_groups

  name_prefix   = "${var.cluster_name}-${each.key}-"
  description   = "Launch template for ${var.cluster_name}-${each.key} node group"

  vpc_security_group_ids = var.node_security_group_ids

  user_data = var.enable_bootstrap_user_data ? base64encode(
    templatefile("${path.module}/templates/userdata.sh.tpl", {
      cluster_name        = var.cluster_name
      endpoint           = var.cluster_endpoint
      cluster_auth_base64 = var.cluster_certificate_authority_data
      bootstrap_extra_args = var.bootstrap_extra_args
      pre_bootstrap_user_data = var.pre_bootstrap_user_data
      post_bootstrap_user_data = var.post_bootstrap_user_data
    })
  ) : null

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = each.value.disk_size
      volume_type          = "gp3"
      iops                 = 3000
      throughput           = 125
      encrypted            = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, each.value.tags, {
      Name = "${var.cluster_name}-${each.key}-node"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, each.value.tags, {
      Name = "${var.cluster_name}-${each.key}-node-volume"
    })
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = merge(local.common_tags, each.value.tags, {
      Name = "${var.cluster_name}-${each.key}-node-eni"
    })
  }

  tags = merge(local.common_tags, each.value.tags, {
    Name = "${var.cluster_name}-${each.key}-launch-template"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# EKS Node Groups
resource "aws_eks_node_group" "main" {
  for_each = local.node_groups

  cluster_name    = var.cluster_name
  node_group_name = each.key
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.subnet_ids

  ami_type        = each.value.ami_type
  capacity_type   = each.value.capacity_type
  instance_types  = each.value.instance_types
  disk_size       = each.value.disk_size

  labels = merge(each.value.labels, {
    "node-group" = each.key
    "environment" = var.environment
  })

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  update_config {
    max_unavailable = each.value.max_unavailable
  }

  launch_template {
    id      = aws_launch_template.node_group[each.key].id
    version = aws_launch_template.node_group[each.key].latest_version
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_launch_template.node_group
  ]

  tags = merge(local.common_tags, each.value.tags, {
    Name = "${var.cluster_name}-${each.key}-node-group"
  })

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# Auto Scaling Group tags for cluster autoscaler
resource "aws_autoscaling_group_tag" "cluster_autoscaler_enabled" {
  for_each = local.node_groups

  autoscaling_group_name = aws_eks_node_group.main[each.key].resources[0].autoscaling_groups[0].name

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = false
  }
}

resource "aws_autoscaling_group_tag" "cluster_autoscaler_cluster_name" {
  for_each = local.node_groups

  autoscaling_group_name = aws_eks_node_group.main[each.key].resources[0].autoscaling_groups[0].name

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }
}
