# Infrastructure - Terraform for EKS

This directory contains Terraform configuration for provisioning the AWS EKS cluster and related infrastructure for the CRM application.

## Related Repositories

- **Application**: [CloudOps_CRM](https://github.com/Barak911/CloudOps_CRM) - Python Flask REST API
- **Cluster Resources**: [CloudOps_CRM_cluster](https://github.com/Barak911/CloudOps_CRM_cluster) - Kubernetes manifests

## Architecture Overview

This Terraform configuration provisions:
- AWS EKS cluster (Kubernetes 1.28)
- VPC with public/private subnets across 2 availability zones
- ECR repository for Docker images
- IAM roles and security groups
- Node group with t3a.medium instances

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials (AWS_PROFILE=Barak)
- kubectl installed
- AWS Account with EKS, VPC, and ECR permissions

## Infrastructure Components

- **EKS Cluster**: Managed Kubernetes cluster using Develeap's external module
- **VPC**: Custom VPC with public and private subnets across 2 AZs
- **ECR Repository**: Docker image registry for application images
- **Node Group**: 1 x t3a.medium instance (cost-optimized)

## Usage

### Initialize Terraform

```bash
terraform init
```

### Plan Infrastructure

```bash
terraform plan
```

### Apply Infrastructure (Start of Study Session)

```bash
terraform apply
```

Review the plan and type `yes` to confirm.

### Configure kubectl

After successful apply, configure kubectl to connect to the cluster:

```bash
aws eks update-kubeconfig --name develeap-eks-cluster --region us-east-1
```

Verify connection:

```bash
kubectl get nodes
```

### Destroy Infrastructure (End of Study Session)

**IMPORTANT**: Always destroy infrastructure when done for the day to avoid costs!

```bash
terraform destroy
```

If destroy fails:
1. Run it again (dependencies often resolve on retry)
2. If it continues to fail, manually delete stuck resources in AWS Console:
   - Load Balancers
   - Security Groups
   - Network Interfaces
   - Elastic IPs

## Cost Optimization

- **Single NAT Gateway**: Reduces NAT gateway costs (vs one per AZ)
- **t3a.medium instances**: Cost-effective instance type
- **1 node only**: Minimum viable cluster size
- **Always destroy when not in use**: Critical for cost control

## Important Notes

- This configuration uses Develeap's EKS Terraform module
- Adjust `cluster_name`, `aws_region` in `variables.tf` if needed
- Consult mentor before increasing node count or instance size
- ECR lifecycle policy keeps only last 10 images to manage storage costs

## Outputs

After `terraform apply`, you'll see:
- Cluster endpoint
- ECR repository URL
- kubectl config command
- VPC and subnet IDs

## File Structure

```
.
├── main.tf              # Main Terraform configuration
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── .gitignore          # Git ignore patterns
└── README.md           # This file
```

## Terraform Modules Used

- `terraform-aws-modules/eks/aws` (~> 20.0) - Official AWS EKS module
- `terraform-aws-modules/vpc/aws` (~> 5.0) - Official AWS VPC module

## Troubleshooting

### Terraform Init Fails
- Check internet connection
- Verify Terraform version: `terraform version`
- Clear cache: `rm -rf .terraform .terraform.lock.hcl` and run `terraform init` again

### Apply Fails with Permission Errors
- Verify AWS credentials: `aws sts get-caller-identity`
- Check IAM permissions for EKS, VPC, ECR
- Ensure AWS_PROFILE is set: `export AWS_PROFILE=Barak`

### Destroy Fails
- Run `terraform destroy` again (first try always recommended)
- Check AWS Console for dependent resources
- Manually delete Load Balancers created by K8S services
- Delete stuck ENIs (Elastic Network Interfaces)
- Force delete security groups if needed

### kubectl Access Issues

If you get "The server has asked for the client to provide credentials":

```bash
# Get your IAM user ARN
PRINCIPAL_ARN=$(aws sts get-caller-identity --query Arn --output text)

# Create EKS access entry
aws eks create-access-entry \
  --cluster-name develeap-eks-cluster \
  --region us-east-1 \
  --principal-arn $PRINCIPAL_ARN

# Associate cluster admin policy
aws eks associate-access-policy \
  --cluster-name develeap-eks-cluster \
  --region us-east-1 \
  --principal-arn $PRINCIPAL_ARN \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

## Next Steps

After infrastructure is provisioned:

1. **Configure kubectl**: `aws eks update-kubeconfig --name develeap-eks-cluster --region us-east-1`
2. **Verify cluster**: `kubectl get nodes`
3. **Deploy application**: Use workflows in the [Application repository](https://github.com/Barak911/CloudOps_CRM)
4. **Deploy manifests**: Apply from [Cluster Resources repository](https://github.com/Barak911/CloudOps_CRM_cluster)

## Contributing

When modifying infrastructure:

1. Test locally: `terraform plan`
2. Review changes carefully
3. Consult with team before changing instance types or node counts
4. Document significant changes in this README

## License

This project is part of a DevOps portfolio demonstrating infrastructure-as-code best practices.
