#!/bin/bash

# EKS Infrastructure Deployment Script
# Usage: ./deploy.sh <environment> [plan|apply|destroy]

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
    echo "Usage: $0 <environment> [action]"
    echo ""
    echo "Environments:"
    echo "  dev     - Development environment"
    echo "  qa      - QA environment"
    echo "  prod    - Production environment"
    echo ""
    echo "Actions:"
    echo "  plan    - Show what Terraform will do (default)"
    echo "  apply   - Apply the Terraform configuration"
    echo "  destroy - Destroy the infrastructure (with confirmation)"
    echo ""
    echo "Examples:"
    echo "  $0 dev plan"
    echo "  $0 qa apply"
    echo "  $0 prod destroy"
}

# Check if environment is provided
if [ $# -lt 1 ]; then
    print_error "Environment not specified"
    show_usage
    exit 1
fi

ENVIRONMENT=$1
ACTION=${2:-plan}

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

# Validate action
case $ACTION in
    plan|apply|destroy)
        print_status "Action: $ACTION"
        ;;
    *)
        print_error "Invalid action: $ACTION"
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
print_status "Working directory: $CONFIG_DIR"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_warning "terraform.tfvars not found. You may need to create it from terraform.tfvars.example"
    if [ -f "terraform.tfvars.example" ]; then
        print_status "Example file available: terraform.tfvars.example"
    fi
fi

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

print_success "Prerequisites check passed"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    print_status "Initializing Terraform..."
    terraform init
    print_success "Terraform initialized"
else
    print_status "Terraform already initialized"
fi

# Validate Terraform configuration
print_status "Validating Terraform configuration..."
terraform validate
print_success "Terraform configuration is valid"

# Execute the action
case $ACTION in
    plan)
        print_status "Running Terraform plan..."
        terraform plan -var-file="terraform.tfvars" -out="tfplan"
        print_success "Terraform plan completed"
        print_status "Plan saved to: tfplan"
        ;;
    apply)
        print_status "Running Terraform apply..."
        if [ -f "tfplan" ]; then
            print_status "Using existing plan file: tfplan"
            terraform apply "tfplan"
        else
            print_warning "No plan file found. Running apply with auto-approve disabled."
            terraform apply -var-file="terraform.tfvars"
        fi
        print_success "Terraform apply completed"
        
        # Show connection instructions
        print_status "Getting cluster information..."
        CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
        AWS_REGION=$(terraform output -raw kubectl_config 2>/dev/null | jq -r '.region' 2>/dev/null || echo "")
        
        if [ -n "$CLUSTER_NAME" ] && [ -n "$AWS_REGION" ]; then
            echo ""
            print_success "Deployment completed successfully!"
            echo ""
            echo "To connect to your EKS cluster, run:"
            echo "  aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME"
            echo ""
            echo "Then verify the connection:"
            echo "  kubectl get nodes"
        fi
        ;;
    destroy)
        print_warning "This will destroy all infrastructure in the $ENVIRONMENT environment!"
        print_warning "This action cannot be undone!"
        echo ""
        read -p "Are you sure you want to continue? (yes/no): " confirm
        
        if [ "$confirm" = "yes" ]; then
            print_status "Running Terraform destroy..."
            terraform destroy -var-file="terraform.tfvars"
            print_success "Terraform destroy completed"
        else
            print_status "Destroy cancelled"
            exit 0
        fi
        ;;
esac

print_success "Script completed successfully"
