terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Uncomment and configure backend for remote state
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "eks/dev/terraform.tfstate"
  #   region = "us-west-2"
  #   dynamodb_table = "terraform-state-locks"
  #   encrypt = true
  # }
}
