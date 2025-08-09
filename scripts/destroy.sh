#!/bin/bash

# EKS Infrastructure Destruction Script
# Usage: ./destroy.sh <environment>

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
    echo "⚠️  WARNING: This script will completely destroy the EKS infrastructure!"
    echo "    This action cannot be undone!"
    echo ""
    echo "The script will:"
    echo "  1. Show what will be destroyed"
    echo "  2. Ask for multiple confirmations"
    echo "  3. Clean up Kubernetes resources first"
    echo "  4. Destroy the Terraform infrastructure"
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

# Extra confirmation for production
if [ "$ENVIRONMENT" = "prod" ]; then
    echo ""
    print_error "⚠️  PRODUCTION ENVIRONMENT DETECTED ⚠️"
    print_error "You are about to destroy the PRODUCTION EKS cluster!"
    print_error "This will result in:"
    print_error "  - Complete loss of all applications and data"
    print_error "  - Service downtime"
    print_error "  - Potential business impact"
    echo ""
    print_warning "Please ensure you have:"
    print_warning "  - Proper authorization to destroy production"
    print_warning "  - Backed up all critical data"
    print_warning "  - Notified all stakeholders"
    print_warning "  - Scheduled maintenance window"
    echo ""
    read -p "Type 'DESTROY PRODUCTION' to continue: " prod_confirm
    
    if [ "$prod_confirm" != "DESTROY PRODUCTION" ]; then
        print_status "Production destruction cancelled"
        exit 0
    fi
fi

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
print_status "Working directory: $CONFIG_DIR"

# Check prerequisites
print_status "Checking prerequisites..."

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed or not in PATH"
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
    print_warning "Terraform state not found. Infrastructure may not exist or may have been destroyed already."
    read -p "Do you want to continue anyway? (yes/no): " continue_confirm
    if [ "$continue_confirm" != "yes" ]; then
        print_status "Destruction cancelled"
        exit 0
    fi
fi

print_success "Prerequisites check passed"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    print_status "Initializing Terraform..."
    terraform init
    print_success "Terraform initialized"
fi

# Show what will be destroyed
print_status "Showing destruction plan..."
terraform plan -destroy -var-file="terraform.tfvars"

echo ""
print_warning "The above resources will be PERMANENTLY DESTROYED!"
echo ""

# Get cluster information if available
CLUSTER_NAME=""
AWS_REGION=""
if terraform output cluster_name &> /dev/null; then
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null)
    AWS_REGION=$(terraform output -raw kubectl_config 2>/dev/null | jq -r '.region' 2>/dev/null)
    
    if [ -n "$CLUSTER_NAME" ] && [ -n "$AWS_REGION" ]; then
        print_status "Cluster to be destroyed: $CLUSTER_NAME in $AWS_REGION"
        
        # Try to clean up Kubernetes resources first
        if command -v kubectl &> /dev/null; then
            print_status "Attempting to clean up Kubernetes resources..."
            
            # Update kubeconfig
            aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" &> /dev/null || true
            
            # Delete all LoadBalancer services to clean up AWS Load Balancers
            print_status "Cleaning up LoadBalancer services..."
            kubectl get svc --all-namespaces -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' | while read namespace name; do
                if [ -n "$namespace" ] && [ -n "$name" ]; then
                    print_status "Deleting LoadBalancer service: $namespace/$name"
                    kubectl delete svc "$name" -n "$namespace" --timeout=60s || true
                fi
            done
            
            # Delete ingress resources
            print_status "Cleaning up Ingress resources..."
            kubectl delete ingress --all --all-namespaces --timeout=60s || true
            
            # Wait a bit for AWS resources to be cleaned up
            print_status "Waiting for AWS resources to be cleaned up..."
            sleep 30
        fi
    fi
fi

# Final confirmation
echo ""
print_error "FINAL CONFIRMATION REQUIRED"
print_error "This will permanently destroy the $ENVIRONMENT EKS infrastructure!"
echo ""
read -p "Type the environment name '$ENVIRONMENT' to confirm destruction: " final_confirm

if [ "$final_confirm" != "$ENVIRONMENT" ]; then
    print_status "Destruction cancelled"
    exit 0
fi

# Additional confirmation with random number
RANDOM_NUM=$((RANDOM % 9000 + 1000))
echo ""
print_warning "As a final safety measure, please enter this number: $RANDOM_NUM"
read -p "Enter the number: " number_confirm

if [ "$number_confirm" != "$RANDOM_NUM" ]; then
    print_status "Destruction cancelled due to incorrect confirmation"
    exit 0
fi

# Perform the destruction
print_status "Starting infrastructure destruction..."
print_warning "This process may take 10-20 minutes..."

# Run terraform destroy
terraform destroy -var-file="terraform.tfvars" -auto-approve

if [ $? -eq 0 ]; then
    print_success "Infrastructure destruction completed successfully"
    
    # Clean up terraform files
    print_status "Cleaning up Terraform files..."
    rm -f tfplan terraform.tfstate.backup
    
    # Remove kubeconfig context if it exists
    if [ -n "$CLUSTER_NAME" ] && command -v kubectl &> /dev/null; then
        CONTEXT_NAME="arn:aws:eks:$AWS_REGION:*:cluster/$CLUSTER_NAME"
        kubectl config delete-context "$CONTEXT_NAME" &> /dev/null || true
        kubectl config delete-cluster "$CONTEXT_NAME" &> /dev/null || true
        kubectl config delete-user "$CONTEXT_NAME" &> /dev/null || true
        print_status "Cleaned up kubectl context"
    fi
    
    echo ""
    print_success "🎉 Destruction completed successfully!"
    print_status "The $ENVIRONMENT EKS infrastructure has been completely removed."
    
else
    print_error "Infrastructure destruction failed!"
    print_error "Please check the errors above and resolve any issues."
    print_status "You may need to manually clean up some resources in the AWS console."
    exit 1
fi
