output "ebs_csi_driver_addon_arn" {
  description = "ARN of the EBS CSI driver addon"
  value       = var.enable_ebs_csi_driver ? aws_eks_addon.ebs_csi_driver[0].arn : null
}

output "ebs_csi_driver_addon_version" {
  description = "Version of the EBS CSI driver addon"
  value       = var.enable_ebs_csi_driver ? aws_eks_addon.ebs_csi_driver[0].addon_version : null
}

output "efs_csi_driver_addon_arn" {
  description = "ARN of the EFS CSI driver addon"
  value       = var.enable_efs_csi_driver ? aws_eks_addon.efs_csi_driver[0].arn : null
}

output "efs_csi_driver_addon_version" {
  description = "Version of the EFS CSI driver addon"
  value       = var.enable_efs_csi_driver ? aws_eks_addon.efs_csi_driver[0].addon_version : null
}

output "aws_load_balancer_controller_status" {
  description = "Status of the AWS Load Balancer Controller Helm release"
  value       = var.enable_aws_load_balancer_controller ? helm_release.aws_load_balancer_controller[0].status : null
}

output "cluster_autoscaler_status" {
  description = "Status of the Cluster Autoscaler Helm release"
  value       = var.enable_cluster_autoscaler ? helm_release.cluster_autoscaler[0].status : null
}

output "metrics_server_status" {
  description = "Status of the Metrics Server Helm release"
  value       = var.enable_metrics_server ? helm_release.metrics_server[0].status : null
}

output "external_dns_status" {
  description = "Status of the External DNS Helm release"
  value       = var.enable_external_dns ? helm_release.external_dns[0].status : null
}

output "cert_manager_status" {
  description = "Status of the cert-manager Helm release"
  value       = var.enable_cert_manager ? helm_release.cert_manager[0].status : null
}

output "ingress_nginx_status" {
  description = "Status of the NGINX Ingress Controller Helm release"
  value       = var.enable_ingress_nginx ? helm_release.ingress_nginx[0].status : null
}

output "installed_addons" {
  description = "List of installed addons"
  value = compact([
    var.enable_ebs_csi_driver ? "aws-ebs-csi-driver" : "",
    var.enable_efs_csi_driver ? "aws-efs-csi-driver" : "",
    var.enable_aws_load_balancer_controller ? "aws-load-balancer-controller" : "",
    var.enable_cluster_autoscaler ? "cluster-autoscaler" : "",
    var.enable_metrics_server ? "metrics-server" : "",
    var.enable_external_dns ? "external-dns" : "",
    var.enable_cert_manager ? "cert-manager" : "",
    var.enable_ingress_nginx ? "ingress-nginx" : ""
  ])
}
