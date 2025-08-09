# EKS Security Guide

This document outlines the security measures implemented in the EKS infrastructure and provides guidelines for maintaining a secure Kubernetes environment.

## Security Architecture Overview

The EKS infrastructure implements defense-in-depth security with multiple layers of protection:

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet                                 │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                   AWS WAF (Optional)                            │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│               Application Load Balancer                         │
│                 + Security Groups                               │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                      VPC                                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 EKS Cluster                             │   │
│  │  ┌─────────────────────────────────────────────────┐   │   │
│  │  │              Worker Nodes                       │   │   │
│  │  │  ┌─────────────────────────────────────────┐   │   │   │
│  │  │  │               Pods                      │   │   │   │
│  │  │  │  + RBAC + Network Policies             │   │   │   │
│  │  │  │  + Pod Security Standards              │   │   │   │
│  │  │  └─────────────────────────────────────────┘   │   │   │
│  │  └─────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Network Security

### 1. VPC Isolation

**Private Subnets:**
- Worker nodes deployed in private subnets
- No direct internet access
- Outbound traffic through NAT Gateways

**Security Groups:**
```hcl
# Cluster Security Group
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-"
  vpc_id      = var.vpc_id
  
  # Only allow necessary traffic
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

# Node Security Group
resource "aws_security_group" "nodes" {
  name_prefix = "${var.cluster_name}-nodes-"
  vpc_id      = var.vpc_id
  
  # Node-to-node communication
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "-1"
    self      = true
  }
}
```

### 2. API Server Access Control

**Private Endpoint (Production):**
```hcl
resource "aws_eks_cluster" "main" {
  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = false  # Production
    public_access_cidrs     = []
  }
}
```

**Authorized Networks:**
```hcl
# Restrict public access to specific CIDRs
endpoint_public_access_cidrs = [
  "203.0.113.0/24",  # Office network
  "198.51.100.0/24"  # VPN network
]
```

### 3. Network Policies

**Default Deny Policy:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**Selective Allow Policy:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

## Identity and Access Management

### 1. Cluster Authentication

**AWS IAM Integration:**
```yaml
# aws-auth ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::123456789012:role/EKSNodeInstanceRole
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
  mapUsers: |
    - userarn: arn:aws:iam::123456789012:user/admin
      username: admin
      groups:
        - system:masters
```

### 2. RBAC Configuration

**Namespace-based Access:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: production
subjects:
- kind: User
  name: developer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

**Service Account Roles:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/AWSLoadBalancerControllerIAMRole
```

### 3. IAM Roles for Service Accounts (IRSA)

**OIDC Provider Configuration:**
```hcl
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}
```

**Service Account Role:**
```hcl
resource "aws_iam_role" "service_account" {
  name = "eks-service-account-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:namespace:service-account-name"
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}
```

## Pod Security

### 1. Pod Security Standards

**Baseline Policy:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-namespace
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Security Context:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: myapp:latest
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      capabilities:
        drop:
        - ALL
```

### 2. Resource Limits

**Resource Quotas:**
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: production
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
```

**Limit Ranges:**
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: production
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
```

### 3. Admission Controllers

**Pod Security Policy (Deprecated) / Pod Security Standards:**
```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
```

## Data Protection

### 1. Encryption at Rest

**EKS Cluster Encryption:**
```hcl
resource "aws_eks_cluster" "main" {
  encryption_config {
    provider {
      key_arn = aws_kms_key.cluster.arn
    }
    resources = ["secrets"]
  }
}
```

**EBS Volume Encryption:**
```hcl
resource "aws_launch_template" "nodes" {
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
      kms_key_id  = aws_kms_key.ebs.arn
    }
  }
}
```

### 2. Encryption in Transit

**TLS Configuration:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: secure-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: arn:aws:acm:region:account:certificate/cert-id
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: https
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
spec:
  type: LoadBalancer
  ports:
  - port: 443
    targetPort: 8443
    protocol: TCP
```

### 3. Secrets Management

**Kubernetes Secrets:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  username: YWRtaW4=
  password: MWYyZDFlMmU2N2Rm
```

**AWS Secrets Manager Integration:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
```

## Monitoring and Auditing

### 1. Audit Logging

**EKS Audit Configuration:**
```hcl
resource "aws_eks_cluster" "main" {
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
}
```

**Audit Policy:**
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  namespaces: ["production"]
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
- level: RequestResponse
  namespaces: ["kube-system"]
  verbs: ["create", "update", "patch", "delete"]
```

### 2. Runtime Security

**Falco Configuration:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-config
data:
  falco.yaml: |
    rules_file:
      - /etc/falco/falco_rules.yaml
      - /etc/falco/k8s_audit_rules.yaml
    json_output: true
    log_syslog: false
```

### 3. Security Scanning

**Image Scanning with ECR:**
```hcl
resource "aws_ecr_repository" "app" {
  name                 = "myapp"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}
```

## Compliance and Governance

### 1. CIS Benchmark Compliance

**Node Configuration:**
```bash
# CIS 4.1.1 - Ensure that the kubelet service file permissions are set to 644
chmod 644 /etc/systemd/system/kubelet.service

# CIS 4.1.2 - Ensure that the kubelet service file ownership is set to root:root
chown root:root /etc/systemd/system/kubelet.service
```

### 2. SOC 2 Compliance

**Access Logging:**
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  omitStages:
  - RequestReceived
  resources:
  - group: ""
    resources: ["*"]
  namespaces: ["production"]
```

### 3. GDPR Compliance

**Data Retention Policies:**
```hcl
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30  # Adjust based on requirements
}
```

## Security Best Practices

### 1. Image Security

**Use Minimal Base Images:**
```dockerfile
FROM gcr.io/distroless/java:11
COPY app.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

**Multi-stage Builds:**
```dockerfile
FROM maven:3.8-openjdk-11 AS build
COPY src /src
COPY pom.xml /
RUN mvn clean package

FROM gcr.io/distroless/java:11
COPY --from=build /target/app.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

### 2. Network Segmentation

**Namespace Isolation:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    name: production
    security-level: high
```

### 3. Regular Updates

**Automated Patching:**
```bash
# Use AWS Systems Manager for node patching
aws ssm create-maintenance-window \
  --name "EKS-Node-Patching" \
  --schedule "cron(0 2 ? * SUN *)"
```

## Incident Response

### 1. Security Event Detection

**CloudWatch Alarms:**
```hcl
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "eks-unauthorized-api-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "AWS/EKS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors unauthorized API calls"
}
```

### 2. Response Procedures

**Immediate Actions:**
1. Isolate affected resources
2. Preserve evidence
3. Assess impact
4. Contain the incident
5. Eradicate the threat
6. Recover services
7. Document lessons learned

### 3. Forensics

**Log Collection:**
```bash
# Collect cluster logs
kubectl logs --all-containers=true --since=24h > cluster-logs.txt

# Collect node logs
aws logs filter-log-events --log-group-name /aws/eks/cluster-name/cluster
```

## Security Tools and Integrations

### 1. Security Scanners

- **Trivy**: Container vulnerability scanning
- **Falco**: Runtime security monitoring
- **OPA Gatekeeper**: Policy enforcement
- **Polaris**: Configuration validation

### 2. Monitoring Tools

- **Prometheus**: Metrics collection
- **Grafana**: Visualization
- **AlertManager**: Alert routing
- **ELK Stack**: Log analysis

### 3. Third-party Integrations

- **Twistlock/Prisma Cloud**: Container security platform
- **Aqua Security**: Cloud-native security
- **Sysdig**: Runtime security and compliance

## Security Checklist

### Pre-Deployment
- [ ] Review IAM permissions
- [ ] Configure network security groups
- [ ] Enable encryption at rest
- [ ] Set up audit logging
- [ ] Configure RBAC policies

### Post-Deployment
- [ ] Verify cluster access controls
- [ ] Test network policies
- [ ] Validate pod security policies
- [ ] Check monitoring and alerting
- [ ] Perform security scan

### Ongoing Maintenance
- [ ] Regular security updates
- [ ] Vulnerability assessments
- [ ] Access reviews
- [ ] Compliance audits
- [ ] Incident response testing

## Contact Information

**Security Team**: security@company.com
**On-call Security**: +1-555-SECURITY
**Incident Response**: incident-response@company.com
