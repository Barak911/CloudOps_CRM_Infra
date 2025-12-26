# Infrastructure Repository

Terraform code for provisioning AWS infrastructure for the CRM application.

## Components

- **VPC** - Default VPC with public subnets
- **EKS Cluster** - Kubernetes 1.31 with managed node groups
- **ECR Repository** - Container registry for CRM application images
- **IAM Roles** - GitHub Actions OIDC role for CI/CD
- **EBS CSI Driver** - For persistent volume support
- **gp3 StorageClass** - Default storage class for PVCs

## Related Repositories

- **Application**: [CloudOps_CRM](https://github.com/Barak911/CloudOps_CRM) - Flask REST API
- **Cluster Resources**: [CloudOps_CRM_cluster](https://github.com/Barak911/CloudOps_CRM_cluster) - Helm charts

## Quick Start

```bash
# Initialize Terraform
terraform init

# Review changes
terraform plan

# Apply infrastructure
terraform apply

# Connect to cluster
aws eks update-kubeconfig --name develeap-eks-cluster --region us-east-1
kubectl get nodes
```

## Configuration

### terraform.tfvars

```hcl
cluster_name            = "develeap-eks-cluster"
github_actions_role_arn = "arn:aws:iam::<ACCOUNT_ID>:role/github-oidc-demo-crm"
developer_user_arn      = "arn:aws:iam::<ACCOUNT_ID>:user/barak"
```

### Key Settings

| Setting | Value | Description |
|---------|-------|-------------|
| Kubernetes Version | 1.31 | EKS cluster version |
| Node Instance Type | t3a.medium | Cost-optimized instance |
| Capacity Type | ON_DEMAND | Reliable node availability |
| Node Scaling | 1-3 nodes | Auto-scaling range |
| Default StorageClass | gp3 | EBS CSI driver with gp3 |

## EKS Cluster Access

Terraform creates EKS Access Entries for:

1. **GitHub Actions OIDC role** - For CI/CD pipelines
2. **Developer IAM user** - For kubectl access

Add ARNs to `terraform.tfvars` before `terraform apply`:

```hcl
github_actions_role_arn = "arn:aws:iam::<ACCOUNT_ID>:role/github-oidc-demo-crm"
developer_user_arn      = "arn:aws:iam::<ACCOUNT_ID>:user/barak"
```

After apply:

```bash
aws eks update-kubeconfig --name develeap-eks-cluster --region us-east-1
kubectl get nodes  # Should work immediately
```

## StorageClass Configuration

The infrastructure includes a default `gp3` StorageClass:

- **Provisioner**: ebs.csi.aws.com (EBS CSI Driver)
- **Type**: gp3 (better performance than gp2)
- **Encrypted**: Yes
- **Binding Mode**: WaitForFirstConsumer

This is required for:
- MongoDB persistent storage
- Elasticsearch data persistence
- Prometheus/Grafana storage

## Files

| File | Description |
|------|-------------|
| `main.tf` | Main configuration |
| `eks.tf` | EKS cluster and node groups |
| `ebs-csi-driver.tf` | EBS CSI addon and StorageClass |
| `iam.tf` | IAM roles for GitHub Actions |
| `provider.tf` | AWS and Kubernetes providers |
| `variables.tf` | Input variables |
| `outputs.tf` | Output values |
| `terraform.tfvars` | Variable values (gitignored) |

## Cleanup

**IMPORTANT**: Run the cleanup-deployment.yml workflow before destroying:

```bash
# 1. Run cleanup workflow in GitHub Actions (deletes K8s resources)

# 2. Destroy infrastructure
terraform destroy
```

This order prevents:
- Orphaned AWS Load Balancers
- ECR repository deletion failures (must be empty)
- Security group deletion failures

## Troubleshooting

### Node Group DEGRADED

If using SPOT instances and node group shows DEGRADED:

```bash
# Check node group status
aws eks describe-nodegroup --cluster-name develeap-eks-cluster \
  --nodegroup-name <nodegroup-name> --region us-east-1
```

Solution: Change `capacity_type` from `"SPOT"` to `"ON_DEMAND"` in `eks.tf`.

### PVC Stuck in Pending

If PersistentVolumeClaims are stuck:

```bash
# Check StorageClasses
kubectl get storageclass

# Should show gp3 as default:
# gp3 (default)   ebs.csi.aws.com   Delete   WaitForFirstConsumer
```

If no default StorageClass, run `terraform apply`.

### Cannot Connect to Cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --name develeap-eks-cluster --region us-east-1

# Verify credentials
aws sts get-caller-identity

# Check access entries
aws eks list-access-entries --cluster-name develeap-eks-cluster --region us-east-1
```

## Cost Optimization

- **ON_DEMAND instances** - More reliable than SPOT for learning projects
- **Single LoadBalancer** - Nginx Ingress serves all services
- **Run `terraform destroy`** - When not actively using the cluster
- **gp3 volumes** - Better price/performance than gp2