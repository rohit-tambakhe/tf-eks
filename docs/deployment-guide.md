# EKS Infrastructure Deployment Guide

## Prerequisites

Before deploying the EKS infrastructure, ensure you have the following tools and configurations in place.

### Required Tools

1. **Terraform** (>= 1.5)
   ```bash
   # Download from https://www.terraform.io/downloads.html
   terraform version
   ```

2. **AWS CLI** (>= 2.0)
   ```bash
   # Install from https://aws.amazon.com/cli/
   aws --version
   ```

3. **kubectl** (>= 1.24)
   ```bash
   # Install from https://kubernetes.io/docs/tasks/tools/
   kubectl version --client
   ```

4. **Helm** (>= 3.0)
   ```bash
   # Install from https://helm.sh/docs/intro/install/
   helm version
   ```

### AWS Configuration

1. **AWS Credentials**
   ```bash
   # Configure AWS credentials
   aws configure
   
   # Or use environment variables
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_DEFAULT_REGION="us-west-2"
   ```

2. **IAM Permissions**
   
   Your AWS user/role needs the following permissions:
   - EC2 (VPC, Subnets, Security Groups, etc.)
   - EKS (Cluster, Node Groups, Addons)
   - IAM (Roles, Policies, OIDC Provider)
   - CloudWatch (Log Groups, Alarms)
   - ELB (Load Balancers, Target Groups)
   - Route53 (if using External DNS)

### Terraform Backend (Recommended)

Configure remote state storage for team collaboration:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "eks/dev/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

## Quick Start

### 1. Clone and Navigate

```bash
cd tf-eks/configs/dev  # or qa/prod
```

### 2. Configure Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit the variables
nano terraform.tfvars
```

### 3. Deploy Infrastructure

```bash
# Using the deployment script (recommended)
../scripts/deploy.sh dev plan
../scripts/deploy.sh dev apply

# Or manually
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### 4. Configure kubectl

```bash
# Using the setup script (recommended)
../scripts/kubectl-setup.sh dev

# Or manually
aws eks update-kubeconfig --region us-west-2 --name eks-dev
kubectl get nodes
```

## Detailed Deployment Steps

### Step 1: Environment Selection

Choose your target environment:

| Environment | Purpose                 | Configuration                            |
|-------------|-------------------------|------------------------------------------|
| `dev`       | Development and testing | Cost-optimized, public access            |
| `qa`        | Quality assurance       | Production-like, enhanced monitoring     |
| `prod`      | Production workloads    | High availability, private access        |

### Step 2: Configuration

Edit the `terraform.tfvars` file for your environment:

```hcl
# Basic Configuration
cluster_name    = "eks-dev"
cluster_version = "1.28"
aws_region      = "us-west-2"
environment     = "dev"

# Network Configuration
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-west-2a", "us-west-2b", "us-west-2c"]

# Node Groups
node_groups = {
  general = {
    instance_types   = ["t3.medium"]
    desired_size    = 2
    max_size        = 4
    min_size        = 1
    # ... other configuration
  }
}

# Feature Flags
enable_cluster_autoscaler           = true
enable_aws_load_balancer_controller = true
enable_monitoring                   = true
```

### Step 3: Initialize Terraform

```bash
cd configs/dev  # or your chosen environment
terraform init
```

This will:
- Download required providers
- Initialize the backend
- Prepare the working directory

### Step 4: Plan Deployment

```bash
terraform plan -var-file="terraform.tfvars" -out="tfplan"
```

Review the plan carefully to ensure:
- Correct resource counts
- Proper naming conventions
- Expected configurations
- No unexpected deletions

### Step 5: Apply Configuration

```bash
terraform apply "tfplan"
```

The deployment typically takes 15-20 minutes and includes:
- VPC and networking components
- EKS cluster creation
- Node group provisioning
- IAM roles and policies
- Security groups
- Addons installation
- Monitoring setup

### Step 6: Verify Deployment

```bash
# Check cluster status
aws eks describe-cluster --name eks-dev --region us-west-2

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name eks-dev

# Verify nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Verify addons
kubectl get pods -n kube-system -l app=aws-load-balancer-controller
kubectl get pods -n kube-system -l app=cluster-autoscaler
```

## Environment-Specific Configurations

### Development Environment

```hcl
# Cost optimization
single_nat_gateway = true
node_groups = {
  general = {
    instance_types = ["t3.medium"]
    desired_size   = 2
    max_size       = 4
    min_size       = 1
  }
}

# Monitoring
enable_cloudwatch_alarms = false
log_retention_days       = 3

# Access
endpoint_public_access = true
```

### QA Environment

```hcl
# Production-like setup
single_nat_gateway = false
node_groups = {
  general = {
    instance_types = ["t3.large"]
    desired_size   = 3
    max_size       = 6
    min_size       = 2
  }
  compute = {
    instance_types = ["m5.large"]
    desired_size   = 2
    max_size       = 4
    min_size       = 1
  }
}

# Enhanced monitoring
enable_cloudwatch_alarms = true
log_retention_days       = 7
```

### Production Environment

```hcl
# High availability
single_nat_gateway = false
node_groups = {
  system = {
    instance_types = ["m5.xlarge"]
    desired_size   = 3
    max_size       = 6
    min_size       = 3
    taints = [{
      key    = "system"
      value  = "true"
      effect = "NO_SCHEDULE"
    }]
  }
  application = {
    instance_types = ["m5.large"]
    desired_size   = 5
    max_size       = 10
    min_size       = 3
  }
}

# Security
endpoint_public_access = false
endpoint_private_access = true

# Comprehensive monitoring
enable_cloudwatch_alarms = true
enable_prometheus        = true
enable_grafana          = true
log_retention_days      = 30
```

## Post-Deployment Tasks

### 1. Install Additional Tools

```bash
# Setup Helm
../scripts/helm-setup.sh dev

# Install useful tools
helm install metrics-server metrics-server/metrics-server -n kube-system
```

### 2. Configure Monitoring

```bash
# Check CloudWatch Container Insights
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/eks-dev"

# Access Grafana (if enabled)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

### 3. Deploy Sample Application

```yaml
# sample-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

```bash
kubectl apply -f sample-app.yaml
kubectl get svc nginx-service
```

## Troubleshooting

### Common Issues

1. **Terraform Init Fails**
   ```bash
   # Clear cache and retry
   rm -rf .terraform
   terraform init
   ```

2. **AWS Permissions Error**
   ```bash
   # Check current user
   aws sts get-caller-identity
   
   # Verify permissions
   aws iam get-user
   aws iam list-attached-user-policies --user-name your-username
   ```

3. **Cluster Access Issues**
   ```bash
   # Update kubeconfig
   aws eks update-kubeconfig --region us-west-2 --name eks-dev
   
   # Check cluster status
   aws eks describe-cluster --name eks-dev --region us-west-2
   ```

4. **Node Group Issues**
   ```bash
   # Check node group status
   aws eks describe-nodegroup --cluster-name eks-dev --nodegroup-name general
   
   # Check Auto Scaling Group
   aws autoscaling describe-auto-scaling-groups
   ```

### Validation Commands

```bash
# Cluster validation
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# Networking validation
kubectl run test-pod --image=busybox --rm -it -- nslookup kubernetes.default

# Storage validation
kubectl get storageclass
kubectl get pv

# Monitoring validation
kubectl top nodes
kubectl top pods --all-namespaces
```

## Cleanup

### Destroy Infrastructure

```bash
# Using the destroy script (recommended)
../scripts/destroy.sh dev

# Or manually
terraform destroy -var-file="terraform.tfvars"
```

⚠️ **Warning**: This will permanently delete all resources. Ensure you have:
- Backed up any important data
- Removed any persistent volumes
- Cleaned up any LoadBalancer services

## Security Considerations

### Network Security

- Use private subnets for worker nodes
- Restrict security group rules
- Enable VPC Flow Logs
- Use private API endpoints in production

### Access Control

- Implement RBAC policies
- Use IAM roles for service accounts
- Enable audit logging
- Regular access reviews

### Data Protection

- Enable encryption at rest
- Use secrets management
- Implement network policies
- Regular security scanning

## Next Steps

1. **Application Deployment**: Deploy your applications using Kubernetes manifests or Helm charts
2. **CI/CD Integration**: Set up automated deployments
3. **Monitoring Setup**: Configure alerting and dashboards
4. **Backup Strategy**: Implement backup and disaster recovery
5. **Security Hardening**: Apply additional security measures
6. **Cost Optimization**: Monitor and optimize costs
