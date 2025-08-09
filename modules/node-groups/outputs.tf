output "node_groups" {
  description = "Map of attribute maps for all EKS node groups created"
  value = {
    for k, v in aws_eks_node_group.main : k => {
      arn                = v.arn
      capacity_type      = v.capacity_type
      cluster_name       = v.cluster_name
      disk_size          = v.disk_size
      instance_types     = v.instance_types
      node_group_name    = v.node_group_name
      release_version    = v.release_version
      remote_access      = v.remote_access
      resources          = v.resources
      scaling_config     = v.scaling_config
      status             = v.status
      subnet_ids         = v.subnet_ids
      tags_all           = v.tags_all
      update_config      = v.update_config
      version            = v.version
    }
  }
}

output "node_group_arns" {
  description = "List of the EKS node group ARNs"
  value       = [for ng in aws_eks_node_group.main : ng.arn]
}

output "node_group_names" {
  description = "List of the EKS node group names"
  value       = [for ng in aws_eks_node_group.main : ng.node_group_name]
}

output "node_group_statuses" {
  description = "Status of the EKS node groups"
  value = {
    for k, v in aws_eks_node_group.main : k => v.status
  }
}

output "node_group_resources" {
  description = "Resources associated with the EKS node groups"
  value = {
    for k, v in aws_eks_node_group.main : k => v.resources
  }
}

output "launch_template_ids" {
  description = "Map of launch template IDs for node groups"
  value = {
    for k, v in aws_launch_template.node_group : k => v.id
  }
}

output "launch_template_arns" {
  description = "Map of launch template ARNs for node groups"
  value = {
    for k, v in aws_launch_template.node_group : k => v.arn
  }
}

output "launch_template_latest_versions" {
  description = "Map of launch template latest versions for node groups"
  value = {
    for k, v in aws_launch_template.node_group : k => v.latest_version
  }
}
