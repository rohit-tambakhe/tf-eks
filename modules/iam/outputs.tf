output "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.cluster.arn
}

output "cluster_role_name" {
  description = "Name of the EKS cluster IAM role"
  value       = aws_iam_role.cluster.name
}

output "node_group_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = aws_iam_role.node_group.arn
}

output "node_group_role_name" {
  description = "Name of the EKS node group IAM role"
  value       = aws_iam_role.node_group.name
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the cluster autoscaler IAM role"
  value       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].arn : null
}

output "cluster_autoscaler_role_name" {
  description = "Name of the cluster autoscaler IAM role"
  value       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].name : null
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}

output "aws_load_balancer_controller_role_name" {
  description = "Name of the AWS Load Balancer Controller IAM role"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller[0].name : null
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = var.enable_ebs_csi_driver ? aws_iam_role.ebs_csi_driver[0].arn : null
}

output "ebs_csi_driver_role_name" {
  description = "Name of the EBS CSI driver IAM role"
  value       = var.enable_ebs_csi_driver ? aws_iam_role.ebs_csi_driver[0].name : null
}

output "efs_csi_driver_role_arn" {
  description = "ARN of the EFS CSI driver IAM role"
  value       = var.enable_efs_csi_driver ? aws_iam_role.efs_csi_driver[0].arn : null
}

output "efs_csi_driver_role_name" {
  description = "Name of the EFS CSI driver IAM role"
  value       = var.enable_efs_csi_driver ? aws_iam_role.efs_csi_driver[0].name : null
}

output "external_dns_role_arn" {
  description = "ARN of the external DNS IAM role"
  value       = var.enable_external_dns ? aws_iam_role.external_dns[0].arn : null
}

output "external_dns_role_name" {
  description = "Name of the external DNS IAM role"
  value       = var.enable_external_dns ? aws_iam_role.external_dns[0].name : null
}
