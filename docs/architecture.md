# EKS Infrastructure Architecture

## Overview

This document describes the architecture of the enterprise-grade Amazon EKS infrastructure deployed using Terraform.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                           AWS Account                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                        VPC                              │    │
│  │                                                         │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │    │
│  │  │   Public    │  │   Public    │  │   Public    │      │    │
│  │  │  Subnet     │  │  Subnet     │  │  Subnet     │      │    │
│  │  │    AZ-A     │  │    AZ-B     │  │    AZ-C     │      │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘      │    │
│  │        │                │                │              │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │    │
│  │  │  Private    │  │  Private    │  │  Private    │      │    │
│  │  │  Subnet     │  │  Subnet     │  │  Subnet     │      │    │
│  │  │    AZ-A     │  │    AZ-B     │  │    AZ-C     │      │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘      │    │
│  │                                                         │    │ 
│  │  ┌─────────────────────────────────────────────────┐    │    │
│  │  │                EKS Cluster                      │    │    │ 
│  │  │                                                 │    │    │
│  │  │  ┌─────────┐  ┌─────────┐  ┌─────────┐          │    │    │
│  │  │  │  Node   │  │  Node   │  │  Node   │          │    │    │
│  │  │  │ Group 1 │  │ Group 2 │  │ Group 3 │          │    │    │
│  │  │  └─────────┘  └─────────┘  └─────────┘          │    │    │
│  │  └─────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   AWS Services                          │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │    │
│  │  │ CloudWatch  │  │     IAM     │  │     ECR     │      │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘      │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │    │
│  │  │     ELB     │  │     EBS     │  │     EFS     │      │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘      │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Virtual Private Cloud (VPC)

The VPC provides isolated network environment for the EKS cluster with the following components:

- **CIDR Block**: Configurable (default: 10.x.0.0/16)
- **Availability Zones**: 3 AZs for high availability
- **Public Subnets**: Host NAT Gateways and Load Balancers
- **Private Subnets**: Host EKS worker nodes
- **Internet Gateway**: Provides internet access
- **NAT Gateways**: Enable outbound internet access for private subnets
- **VPC Endpoints**: Direct access to AWS services (S3, ECR, EC2)

### 2. EKS Cluster

The managed Kubernetes control plane with:

- **Control Plane**: Fully managed by AWS
- **API Server**: Private and/or public endpoint access
- **OIDC Provider**: For service account authentication
- **Encryption**: At-rest encryption using KMS
- **Logging**: CloudWatch integration for audit logs

### 3. Node Groups

Managed worker nodes with:

- **Auto Scaling Groups**: Automatic scaling based on demand
- **Launch Templates**: Consistent node configuration
- **Multiple Instance Types**: Optimized for different workloads
- **Spot Instances**: Cost optimization for non-critical workloads
- **Taints and Labels**: Workload isolation and scheduling

### 4. Security Groups

Network security with:

- **Cluster Security Group**: Controls access to EKS API server
- **Node Security Group**: Controls traffic between nodes
- **ALB Security Group**: Controls load balancer access
- **VPC Endpoint Security Group**: Secure access to AWS services

### 5. IAM Roles and Policies

Identity and access management:

- **Cluster Service Role**: EKS cluster permissions
- **Node Instance Role**: Worker node permissions
- **Service Account Roles**: Fine-grained permissions for addons
- **OIDC Integration**: Kubernetes service account to IAM role mapping

## Network Architecture

### Subnet Design

| Subnet Type | Purpose                   | CIDR                                      | Resources                    |
|-------------|---------------------------|-------------------------------------------|------------------------------|
| Public      | Internet-facing resources | 10.x.1.0/24, 10.x.2.0/24, 10.x.3.0/24   | NAT Gateways, Load Balancers |
| Private     | Internal resources        | 10.x.10.0/24, 10.x.20.0/24, 10.x.30.0/24 | EKS Nodes, Pods              |

### Traffic Flow

1. **Inbound Traffic**: Internet → ALB → Kubernetes Services → Pods
2. **Outbound Traffic**: Pods → NAT Gateway → Internet
3. **Internal Traffic**: Pod-to-Pod communication within VPC
4. **AWS Services**: Direct access via VPC Endpoints

## Security Architecture

### Defense in Depth

1. **Network Level**:
   - VPC isolation
   - Security groups (stateful firewall)
   - Private subnets for worker nodes
   - VPC Flow Logs for monitoring

2. **Cluster Level**:
   - Private API endpoint (production)
   - RBAC (Role-Based Access Control)
   - Pod Security Standards
   - Network Policies

3. **Node Level**:
   - Hardened AMIs
   - Instance metadata service v2
   - Systems Manager for patching
   - Container runtime security

4. **Application Level**:
   - Service mesh (optional)
   - Mutual TLS
   - Application-level encryption
   - Secrets management

### IAM Integration

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Kubernetes     │    │      OIDC       │    │      IAM        │
│ Service Account │────│   Provider      │────│     Role        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Monitoring and Observability

### CloudWatch Integration

- **Container Insights**: Cluster and node metrics
- **Log Groups**: Centralized logging
- **Alarms**: Proactive monitoring
- **Dashboards**: Visual monitoring

### Prometheus Stack (Optional)

- **Prometheus**: Metrics collection
- **Grafana**: Visualization and dashboards
- **AlertManager**: Alert routing and management

## High Availability

### Multi-AZ Deployment

- Control plane spans 3 AZs automatically
- Worker nodes distributed across AZs
- Load balancers with cross-AZ routing
- Data replication across AZs

### Fault Tolerance

- Auto Scaling Groups for node replacement
- Health checks and automatic remediation
- Rolling updates with zero downtime
- Backup and disaster recovery procedures

## Scalability

### Horizontal Scaling

- **Cluster Autoscaler**: Automatic node scaling
- **Horizontal Pod Autoscaler**: Pod-level scaling
- **Vertical Pod Autoscaler**: Resource optimization

### Performance Optimization

- **Instance Types**: Optimized for workload requirements
- **Storage**: EBS GP3 with optimized IOPS
- **Networking**: Enhanced networking capabilities
- **Container Insights**: Performance monitoring

## Environment Differences

### Development
- Single NAT Gateway (cost optimization)
- Smaller instance types
- Public API endpoint allowed
- Minimal monitoring

### QA
- Production-like setup
- Medium instance types
- Enhanced monitoring
- Mixed endpoint access

### Production
- Multiple NAT Gateways (HA)
- Production-grade instances
- Private API endpoint only
- Comprehensive monitoring
- Full security hardening

## Compliance and Governance

### Tagging Strategy

All resources are tagged with:
- Environment
- Project
- Owner
- Cost Center
- Compliance requirements

### Backup Strategy

- EBS snapshots
- Configuration backups
- Disaster recovery procedures
- Regular testing

### Cost Optimization

- Spot instances for non-critical workloads
- Right-sizing recommendations
- Resource scheduling
- Cost monitoring and alerting
