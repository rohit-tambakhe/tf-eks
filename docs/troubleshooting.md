# EKS Infrastructure Troubleshooting Guide

This guide covers common issues and their solutions when deploying and managing the EKS infrastructure.

## Table of Contents

1. [Terraform Issues](#terraform-issues)
2. [AWS Authentication and Permissions](#aws-authentication-and-permissions)
3. [EKS Cluster Issues](#eks-cluster-issues)
4. [Node Group Issues](#node-group-issues)
5. [Networking Issues](#networking-issues)
6. [Addon Issues](#addon-issues)
7. [Monitoring and Logging Issues](#monitoring-and-logging-issues)
8. [Performance Issues](#performance-issues)
9. [Security Issues](#security-issues)
10. [Cost and Billing Issues](#cost-and-billing-issues)

## Terraform Issues

### 1. Terraform Init Fails

**Symptoms:**
```
Error: Failed to query available provider packages
```

**Solutions:**
```bash
# Clear Terraform cache
rm -rf .terraform .terraform.lock.hcl

# Re-initialize
terraform init

# If using custom backend, verify configuration
terraform init -backend-config="bucket=your-state-bucket"
```

### 2. State Lock Issues

**Symptoms:**
```
Error: Error acquiring the state lock
```

**Solutions:**
```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID

# Check DynamoDB table for locks
aws dynamodb scan --table-name terraform-state-locks
```

### 3. Provider Version Conflicts

**Symptoms:**
```
Error: Inconsistent dependency lock file
```

**Solutions:**
```bash
# Update provider versions
terraform init -upgrade

# Or reset lock file
rm .terraform.lock.hcl
terraform init
```

### 4. Resource Already Exists

**Symptoms:**
```
Error: resource already exists
```

**Solutions:**
```bash
# Import existing resource
terraform import aws_vpc.main vpc-12345678

# Or remove from state if not needed
terraform state rm aws_vpc.main
```

## AWS Authentication and Permissions

### 1. AWS Credentials Not Configured

**Symptoms:**
```
Error: No valid credential sources found
```

**Solutions:**
```bash
# Configure credentials
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-west-2"

# Verify configuration
aws sts get-caller-identity
```

### 2. Insufficient IAM Permissions

**Symptoms:**
```
Error: User is not authorized to perform: eks:CreateCluster
```

**Solutions:**
```bash
# Check current user permissions
aws iam get-user
aws iam list-attached-user-policies --user-name your-username

# Required policies for EKS deployment:
# - AmazonEKSClusterPolicy
# - AmazonEKSWorkerNodePolicy
# - AmazonEKS_CNI_Policy
# - AmazonEC2ContainerRegistryReadOnly
# - Custom policies for VPC, IAM, CloudWatch
```

### 3. MFA Token Required

**Symptoms:**
```
Error: MultiFactorAuthentication required
```

**Solutions:**
```bash
# Use AWS STS to assume role with MFA
aws sts assume-role --role-arn arn:aws:iam::123456789012:role/EKSAdminRole \
  --role-session-name eks-session \
  --serial-number arn:aws:iam::123456789012:mfa/username \
  --token-code 123456
```

## EKS Cluster Issues

### 1. Cluster Creation Fails

**Symptoms:**
```
Error: error creating EKS Cluster: InvalidParameterException
```

**Common Causes and Solutions:**

**Subnet Issues:**
```bash
# Verify subnets span at least 2 AZs
aws ec2 describe-subnets --subnet-ids subnet-12345 subnet-67890

# Check subnet tags
aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/cluster/cluster-name,Values=shared"
```

**Service Role Issues:**
```bash
# Verify IAM role exists and has correct policies
aws iam get-role --role-name eks-cluster-role
aws iam list-attached-role-policies --role-name eks-cluster-role
```

### 2. Cluster Endpoint Access Issues

**Symptoms:**
```
Error: unable to connect to cluster
```

**Solutions:**
```bash
# Check cluster endpoint configuration
aws eks describe-cluster --name your-cluster --query 'cluster.endpoint'

# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name your-cluster

# For private endpoint access, ensure you're in the VPC or connected via VPN
```

### 3. OIDC Provider Issues

**Symptoms:**
```
Error: error creating IAM OIDC provider
```

**Solutions:**
```bash
# Check if OIDC provider already exists
aws iam list-open-id-connect-providers

# Verify cluster OIDC issuer URL
aws eks describe-cluster --name your-cluster --query 'cluster.identity.oidc.issuer'
```

## Node Group Issues

### 1. Node Group Creation Fails

**Symptoms:**
```
Error: error creating EKS Node Group
```

**Common Solutions:**

**Instance Type Availability:**
```bash
# Check instance type availability in your AZs
aws ec2 describe-instance-type-offerings --location-type availability-zone \
  --filters Name=instance-type,Values=t3.medium
```

**Subnet Configuration:**
```bash
# Ensure subnets have available IP addresses
aws ec2 describe-subnets --subnet-ids subnet-12345 \
  --query 'Subnets[0].AvailableIpAddressCount'
```

**Launch Template Issues:**
```bash
# Check launch template configuration
aws ec2 describe-launch-template-versions --launch-template-id lt-12345
```

### 2. Nodes Not Joining Cluster

**Symptoms:**
- Nodes appear in Auto Scaling Group but not in `kubectl get nodes`

**Solutions:**
```bash
# Check node group status
aws eks describe-nodegroup --cluster-name your-cluster --nodegroup-name your-nodegroup

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names your-asg

# Check CloudWatch logs for kubelet errors
aws logs filter-log-events --log-group-name /aws/eks/your-cluster/cluster
```

### 3. Node Scaling Issues

**Symptoms:**
- Cluster Autoscaler not scaling nodes

**Solutions:**
```bash
# Check Cluster Autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler

# Verify Auto Scaling Group tags
aws autoscaling describe-tags --filters Name=auto-scaling-group,Values=your-asg

# Required tags:
# k8s.io/cluster-autoscaler/enabled = true
# k8s.io/cluster-autoscaler/cluster-name = owned
```

## Networking Issues

### 1. Pod-to-Pod Communication Issues

**Symptoms:**
- Pods cannot communicate with each other

**Solutions:**
```bash
# Check VPC CNI plugin
kubectl get pods -n kube-system -l k8s-app=aws-node

# Verify security group rules
aws ec2 describe-security-groups --group-ids sg-12345

# Check network policies
kubectl get networkpolicies --all-namespaces
```

### 2. Internet Access Issues

**Symptoms:**
- Pods cannot access internet

**Solutions:**
```bash
# Check NAT Gateway configuration
aws ec2 describe-nat-gateways

# Verify route tables
aws ec2 describe-route-tables --filters Name=vpc-id,Values=vpc-12345

# Check DNS resolution
kubectl run test-pod --image=busybox --rm -it -- nslookup google.com
```

### 3. Load Balancer Issues

**Symptoms:**
- LoadBalancer services stuck in pending state

**Solutions:**
```bash
# Check AWS Load Balancer Controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify subnet tags for load balancer discovery
# Public subnets need: kubernetes.io/role/elb = 1
# Private subnets need: kubernetes.io/role/internal-elb = 1

# Check service annotations
kubectl describe service your-service
```

## Addon Issues

### 1. AWS Load Balancer Controller Issues

**Symptoms:**
```
Error: failed to create load balancer
```

**Solutions:**
```bash
# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify IAM role and policies
aws iam get-role --role-name AWSLoadBalancerControllerIAMRole

# Check service account annotations
kubectl describe serviceaccount aws-load-balancer-controller -n kube-system
```

### 2. EBS CSI Driver Issues

**Symptoms:**
- Persistent volumes stuck in pending state

**Solutions:**
```bash
# Check EBS CSI driver pods
kubectl get pods -n kube-system -l app=ebs-csi-controller

# Verify storage class
kubectl get storageclass

# Check PVC events
kubectl describe pvc your-pvc
```

### 3. Cluster Autoscaler Issues

**Symptoms:**
- Nodes not scaling automatically

**Solutions:**
```bash
# Check autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler

# Verify node group configuration
aws eks describe-nodegroup --cluster-name your-cluster --nodegroup-name your-nodegroup

# Check pod resource requests
kubectl top pods --all-namespaces
```

## Monitoring and Logging Issues

### 1. CloudWatch Container Insights Not Working

**Symptoms:**
- No metrics in CloudWatch Container Insights

**Solutions:**
```bash
# Check CloudWatch agent
kubectl get pods -n amazon-cloudwatch

# Verify log groups
aws logs describe-log-groups --log-group-name-prefix "/aws/containerinsights/"

# Check IAM permissions for CloudWatch
aws iam get-role --role-name CloudWatchAgentServerRole
```

### 2. Fluent Bit Logging Issues

**Symptoms:**
- Application logs not appearing in CloudWatch

**Solutions:**
```bash
# Check Fluent Bit pods
kubectl get pods -n kube-system -l k8s-app=fluent-bit

# Check Fluent Bit logs
kubectl logs -n kube-system daemonset/fluent-bit

# Verify log group configuration
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/"
```

### 3. Prometheus/Grafana Issues

**Symptoms:**
- Monitoring stack not accessible

**Solutions:**
```bash
# Check monitoring namespace
kubectl get pods -n monitoring

# Verify Prometheus configuration
kubectl logs -n monitoring statefulset/prometheus-kube-prometheus-prometheus

# Check Grafana service
kubectl get svc -n monitoring prometheus-grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

## Performance Issues

### 1. High CPU/Memory Usage

**Symptoms:**
- Nodes running out of resources

**Solutions:**
```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Identify resource-heavy pods
kubectl get pods --all-namespaces --sort-by='.status.containerStatuses[0].restartCount'

# Check for resource limits
kubectl describe pod your-pod
```

### 2. Slow Pod Startup

**Symptoms:**
- Pods take long time to start

**Solutions:**
```bash
# Check image pull times
kubectl describe pod your-pod

# Verify ECR authentication
aws ecr get-login-token --region us-west-2

# Check node capacity
kubectl describe node your-node
```

## Security Issues

### 1. RBAC Permission Denied

**Symptoms:**
```
Error: User cannot list pods in namespace
```

**Solutions:**
```bash
# Check current user context
kubectl config current-context

# Verify RBAC configuration
kubectl get rolebindings,clusterrolebindings --all-namespaces

# Test permissions
kubectl auth can-i list pods --namespace default
```

### 2. Service Account Issues

**Symptoms:**
- Pods cannot access AWS services

**Solutions:**
```bash
# Check service account annotations
kubectl describe serviceaccount your-service-account

# Verify IAM role trust policy
aws iam get-role --role-name your-role

# Check pod environment variables
kubectl describe pod your-pod | grep -A 10 Environment
```

## Cost and Billing Issues

### 1. Unexpected High Costs

**Symptoms:**
- AWS bill higher than expected

**Solutions:**
```bash
# Check running resources
aws ec2 describe-instances --filters Name=instance-state-name,Values=running
aws elbv2 describe-load-balancers
aws eks list-clusters

# Review Cost Explorer
# Check for unused resources:
# - Idle load balancers
# - Unused EBS volumes
# - Over-provisioned nodes

# Optimize instance types
kubectl top nodes
aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceType'
```

### 2. Spot Instance Issues

**Symptoms:**
- Frequent node replacements

**Solutions:**
```bash
# Check spot instance interruption notices
kubectl get events --field-selector reason=SpotInterruption

# Review spot instance pricing history
aws ec2 describe-spot-price-history --instance-types t3.medium

# Configure graceful handling
kubectl describe pod your-pod | grep -A 5 "Termination Grace Period"
```

## General Debugging Commands

### Cluster Information
```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods --all-namespaces
kubectl get services --all-namespaces
```

### Resource Status
```bash
kubectl describe node node-name
kubectl describe pod pod-name -n namespace
kubectl logs pod-name -n namespace
kubectl get events --sort-by=.metadata.creationTimestamp
```

### AWS Resources
```bash
aws eks describe-cluster --name cluster-name
aws ec2 describe-instances
aws elbv2 describe-load-balancers
aws logs describe-log-groups
```

### Network Debugging
```bash
kubectl run netshoot --rm -it --image nicolaka/netshoot -- /bin/bash
kubectl exec -it pod-name -- nslookup kubernetes.default
kubectl get endpoints
```

## Getting Help

### AWS Support
- AWS Support Console
- AWS Forums
- AWS Documentation

### Community Resources
- Kubernetes Slack
- EKS GitHub Issues
- Stack Overflow

### Internal Resources
- Infrastructure team
- DevOps documentation
- Runbooks and playbooks

### Emergency Contacts
- On-call engineer: [contact info]
- Infrastructure team lead: [contact info]
- AWS TAM (if applicable): [contact info]
