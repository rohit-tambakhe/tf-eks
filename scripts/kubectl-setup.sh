#!/bin/bash

# kubectl Setup Script for EKS
# Usage: ./kubectl-setup.sh <environment>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <environment>"
    echo ""
    echo "Environments:"
    echo "  dev     - Development environment"
    echo "  qa      - QA environment"
    echo "  prod    - Production environment"
    echo ""
    echo "This script will:"
    echo "  1. Configure kubectl for the specified EKS cluster"
    echo "  2. Verify the connection"
    echo "  3. Show cluster information"
    echo "  4. List available nodes and pods"
}

# Check if environment is provided
if [ $# -lt 1 ]; then
    print_error "Environment not specified"
    show_usage
    exit 1
fi

ENVIRONMENT=$1

# Validate environment
case $ENVIRONMENT in
    dev|qa|prod)
        print_status "Environment: $ENVIRONMENT"
        ;;
    *)
        print_error "Invalid environment: $ENVIRONMENT"
        show_usage
        exit 1
        ;;
esac

# Set working directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT/configs/$ENVIRONMENT"

# Check if config directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    print_error "Configuration directory not found: $CONFIG_DIR"
    exit 1
fi

# Change to config directory
cd "$CONFIG_DIR"

# Check prerequisites
print_status "Checking prerequisites..."

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    print_status "Install kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed or not in PATH"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured or invalid"
    exit 1
fi

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
    print_error "Terraform state not found. Has the infrastructure been deployed?"
    exit 1
fi

print_success "Prerequisites check passed"

# Get cluster information from Terraform outputs
print_status "Getting cluster information from Terraform..."

CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$CLUSTER_NAME" ]; then
    print_error "Could not get cluster name from Terraform output"
    exit 1
fi

AWS_REGION=$(terraform output -raw kubectl_config 2>/dev/null | jq -r '.region' 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$AWS_REGION" ]; then
    print_error "Could not get AWS region from Terraform output"
    exit 1
fi

print_status "Cluster Name: $CLUSTER_NAME"
print_status "AWS Region: $AWS_REGION"

# Update kubeconfig
print_status "Updating kubeconfig..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

if [ $? -eq 0 ]; then
    print_success "kubeconfig updated successfully"
else
    print_error "Failed to update kubeconfig"
    exit 1
fi

# Verify connection
print_status "Verifying cluster connection..."
kubectl cluster-info

if [ $? -eq 0 ]; then
    print_success "Successfully connected to cluster"
else
    print_error "Failed to connect to cluster"
    exit 1
fi

# Show cluster information
echo ""
print_status "Cluster Information:"
echo "===================="

# Get cluster version
CLUSTER_VERSION=$(kubectl version --short 2>/dev/null | grep "Server Version" | cut -d' ' -f3)
echo "Kubernetes Version: $CLUSTER_VERSION"

# Get nodes
echo ""
print_status "Cluster Nodes:"
kubectl get nodes -o wide

# Get node groups info
echo ""
print_status "Node Groups Information:"
NODE_GROUPS=$(terraform output -json node_groups 2>/dev/null | jq -r 'keys[]' 2>/dev/null)
if [ -n "$NODE_GROUPS" ]; then
    echo "$NODE_GROUPS"
else
    echo "Could not retrieve node group information"
fi

# Get system pods
echo ""
print_status "System Pods (kube-system namespace):"
kubectl get pods -n kube-system

# Check for monitoring namespace
if kubectl get namespace monitoring &> /dev/null; then
    echo ""
    print_status "Monitoring Pods (monitoring namespace):"
    kubectl get pods -n monitoring
fi

# Show useful commands
echo ""
print_success "Setup completed successfully!"
echo ""
print_status "Useful commands:"
echo "  kubectl get nodes                    # List all nodes"
echo "  kubectl get pods --all-namespaces   # List all pods"
echo "  kubectl get svc --all-namespaces    # List all services"
echo "  kubectl top nodes                   # Node resource usage (requires metrics-server)"
echo "  kubectl top pods --all-namespaces   # Pod resource usage"
echo ""
print_status "Monitoring and logging:"
echo "  kubectl logs -n kube-system -l app=aws-load-balancer-controller  # ALB Controller logs"
echo "  kubectl logs -n kube-system -l app=cluster-autoscaler            # Cluster Autoscaler logs"
echo "  kubectl get events --sort-by=.metadata.creationTimestamp         # Recent events"
echo ""

# Show context information
CURRENT_CONTEXT=$(kubectl config current-context)
print_status "Current kubectl context: $CURRENT_CONTEXT"

# Backup current config
KUBECONFIG_BACKUP="$HOME/.kube/config.backup.$(date +%Y%m%d_%H%M%S)"
cp "$HOME/.kube/config" "$KUBECONFIG_BACKUP" 2>/dev/null && \
    print_status "Kubeconfig backed up to: $KUBECONFIG_BACKUP" || \
    print_warning "Could not backup kubeconfig"
