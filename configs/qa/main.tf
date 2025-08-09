# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  cluster_name         = var.cluster_name
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  
  enable_nat_gateway    = true
  single_nat_gateway    = var.single_nat_gateway
  enable_dns_hostnames  = true
  enable_dns_support    = true
  enable_flow_log       = true
  enable_vpc_endpoints  = true
  
  flow_log_retention_days = var.log_retention_days
  environment            = var.environment
  tags                   = var.tags
}

# Security Groups Module
module "security_groups" {
  source = "../../modules/security-groups"

  cluster_name                = var.cluster_name
  vpc_id                     = module.vpc.vpc_id
  vpc_cidr_block             = module.vpc.vpc_cidr_block
  environment                = var.environment
  enable_cluster_api_access  = var.endpoint_public_access
  cluster_api_access_cidrs   = var.endpoint_public_access_cidrs
  tags                       = var.tags
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  cluster_name                         = var.cluster_name
  environment                         = var.environment
  enable_cluster_autoscaler           = var.enable_cluster_autoscaler
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  enable_ebs_csi_driver               = var.enable_ebs_csi_driver
  enable_external_dns                 = var.enable_external_dns
  tags                                = var.tags
}

# EKS Cluster Module
module "eks_cluster" {
  source = "../../modules/eks-cluster"

  cluster_name                           = var.cluster_name
  cluster_version                        = var.cluster_version
  vpc_id                                = module.vpc.vpc_id
  subnet_ids                            = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  cluster_service_role_arn              = module.iam.cluster_role_arn
  cluster_security_group_ids            = [module.security_groups.cluster_security_group_id]
  
  endpoint_private_access               = var.endpoint_private_access
  endpoint_public_access                = var.endpoint_public_access
  endpoint_public_access_cidrs          = var.endpoint_public_access_cidrs
  
  cluster_encryption_config_enabled     = true
  enabled_cluster_log_types             = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cluster_log_retention_in_days         = var.log_retention_days
  
  environment = var.environment
  tags        = var.tags

  depends_on = [module.vpc, module.security_groups, module.iam]
}

# Update IAM module with OIDC provider information
module "iam_with_oidc" {
  source = "../../modules/iam"

  cluster_name                         = var.cluster_name
  environment                         = var.environment
  oidc_provider_arn                   = module.eks_cluster.oidc_provider_arn
  oidc_provider_url                   = module.eks_cluster.oidc_provider_url
  enable_cluster_autoscaler           = var.enable_cluster_autoscaler
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  enable_ebs_csi_driver               = var.enable_ebs_csi_driver
  enable_external_dns                 = var.enable_external_dns
  tags                                = var.tags

  depends_on = [module.eks_cluster]
}

# Node Groups Module
module "node_groups" {
  source = "../../modules/node-groups"

  cluster_name                      = var.cluster_name
  cluster_endpoint                  = module.eks_cluster.cluster_endpoint
  cluster_certificate_authority_data = module.eks_cluster.cluster_certificate_authority_data
  cluster_security_group_id         = module.eks_cluster.cluster_security_group_id
  node_group_role_arn               = module.iam.node_group_role_arn
  subnet_ids                        = module.vpc.private_subnet_ids
  node_security_group_ids           = [module.security_groups.node_group_security_group_id]
  
  node_groups = var.node_groups
  
  environment = var.environment
  tags        = var.tags

  depends_on = [module.eks_cluster, module.iam]
}

# EKS Addons Module
module "addons" {
  source = "../../modules/addons"

  cluster_name     = var.cluster_name
  cluster_endpoint = module.eks_cluster.cluster_endpoint
  cluster_version  = var.cluster_version
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  
  enable_ebs_csi_driver                             = var.enable_ebs_csi_driver
  ebs_csi_driver_service_account_role_arn           = module.iam_with_oidc.ebs_csi_driver_role_arn
  enable_aws_load_balancer_controller               = var.enable_aws_load_balancer_controller
  aws_load_balancer_controller_service_account_role_arn = module.iam_with_oidc.aws_load_balancer_controller_role_arn
  enable_cluster_autoscaler                         = var.enable_cluster_autoscaler
  cluster_autoscaler_service_account_role_arn       = module.iam_with_oidc.cluster_autoscaler_role_arn
  enable_metrics_server                             = var.enable_metrics_server
  enable_external_dns                               = var.enable_external_dns
  external_dns_service_account_role_arn             = module.iam_with_oidc.external_dns_role_arn
  enable_cert_manager                               = var.enable_cert_manager
  
  environment = var.environment
  tags        = var.tags

  depends_on = [module.node_groups, module.iam_with_oidc]
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  cluster_name                = var.cluster_name
  vpc_id                     = module.vpc.vpc_id
  enable_container_insights  = var.enable_container_insights
  enable_fluent_bit          = var.enable_fluent_bit
  enable_cloudwatch_alarms   = var.enable_cloudwatch_alarms
  alarm_notification_emails  = var.alarm_notification_emails
  log_retention_days         = var.log_retention_days
  
  environment = var.environment
  tags        = var.tags

  depends_on = [module.eks_cluster, module.node_groups]
}
