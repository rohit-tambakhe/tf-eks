output "cluster_security_group_id" {
  description = "ID of the EKS cluster security group"
  value       = aws_security_group.cluster.id
}

output "node_group_security_group_id" {
  description = "ID of the EKS node group security group"
  value       = aws_security_group.node_group.id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

output "efs_security_group_id" {
  description = "ID of the EFS security group"
  value       = aws_security_group.efs.id
}

output "cluster_security_group_arn" {
  description = "ARN of the EKS cluster security group"
  value       = aws_security_group.cluster.arn
}

output "node_group_security_group_arn" {
  description = "ARN of the EKS node group security group"
  value       = aws_security_group.node_group.arn
}

output "alb_security_group_arn" {
  description = "ARN of the ALB security group"
  value       = aws_security_group.alb.arn
}

output "rds_security_group_arn" {
  description = "ARN of the RDS security group"
  value       = aws_security_group.rds.arn
}

output "efs_security_group_arn" {
  description = "ARN of the EFS security group"
  value       = aws_security_group.efs.arn
}
