# Enterprise EKS Terraform Infrastructure

This repository contains a comprehensive Terraform project for deploying enterprise-grade Amazon EKS clusters across multiple environments (DEV, QA, PROD) using reusable modules.

## Project Structure

```
tf-eks/
├── modules/
│   ├── vpc/                 # VPC with multi-AZ networking
│   ├── eks-cluster/         # EKS cluster configuration
│   ├── node-groups/         # Managed node groups
│   ├── security-groups/     # Security group configurations
│   ├── iam/                # IAM roles and policies
│   ├── addons/             # EKS addons and extensions
│   └── monitoring/         # CloudWatch and monitoring
├── configs/
│   ├── dev/                # Development environment
│   ├── qa/                 # QA environment
│   └── prod/               # Production environment
├── scripts/                # Utility scripts
├── docs/                   # Documentation
├── .gitignore
├── README.md
└── versions.tf
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- kubectl
- Helm 3.x

## Quick Start

### 1. Environment Setup

Choose your target environment and navigate to the appropriate config directory:

```bash
cd configs/dev    # for development
cd configs/qa     # for QA
cd configs/prod   # for production
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan Deployment

```bash
terraform plan -var-file="terraform.tfvars"
```

### 4. Deploy Infrastructure

```bash
terraform apply -var-file="terraform.tfvars"
```

### 5. Configure kubectl

```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

## Module Documentation

### VPC Module
- Creates VPC with public and private subnets across 3 AZs
- Configures Internet Gateway and NAT Gateways
- Sets up VPC endpoints for S3 and ECR
- Implements proper subnet tagging for EKS

### EKS Cluster Module
- Deploys EKS cluster with configurable version
- Configures OIDC identity provider
- Sets up CloudWatch logging
- Implements cluster encryption

### Node Groups Module
- Creates managed node groups with auto-scaling
- Supports multiple instance types and spot instances
- Configures launch templates with user data
- Implements taints and labels for workload isolation

### Security Groups Module
- Creates security groups for cluster, nodes, and ALB
- Implements principle of least privilege
- Environment-specific rule configurations

### IAM Module
- Creates EKS cluster and node group roles
- Sets up service account roles for addons
- Implements OIDC provider configuration

### Addons Module
- Deploys essential EKS addons (VPC CNI, CoreDNS, kube-proxy)
- Installs AWS Load Balancer Controller
- Configures Cluster Autoscaler and Metrics Server

### Monitoring Module
- Sets up CloudWatch Container Insights
- Configures logging with Fluent Bit
- Creates CloudWatch alarms and SNS notifications

## Environment Configurations

### Development (DEV)
- Cost-optimized with smaller instances
- Single NAT Gateway
- Basic monitoring
- Public endpoint access allowed

### QA
- Production-like setup for testing
- Medium instance types
- Enhanced monitoring
- Mixed endpoint access

### Production (PROD)
- High availability across multiple AZs
- Production-grade instances
- Comprehensive monitoring
- Private endpoint only
- Enhanced security

## Security Features

- Encryption at rest and in transit
- Network segmentation with private subnets
- IAM roles with minimal permissions
- Audit logging enabled
- Security group restrictions
- VPC Flow Logs

## Monitoring and Observability

- CloudWatch Container Insights
- Comprehensive logging strategy
- Metrics collection and alerting
- Health checks and dashboards
- Cost monitoring

## Cost Optimization

- Environment-specific instance sizing
- Spot instance support for non-critical workloads
- Resource tagging for cost allocation
- Automated scaling policies

## Troubleshooting

Common issues and solutions are documented in `docs/troubleshooting.md`.

## Contributing

1. Follow Terraform best practices
2. Update documentation for any changes
3. Test in DEV environment first
4. Use consistent naming conventions
5. Implement proper resource tagging

## Support

For issues and questions, please refer to the documentation in the `docs/` directory or contact the infrastructure team.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
