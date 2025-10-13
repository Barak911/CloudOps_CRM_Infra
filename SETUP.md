# EKS Infrastructure Setup Guide

This guide ensures you can deploy and access the EKS cluster without authentication issues.

## Prerequisites

1. **AWS CLI installed and configured**
   ```bash
   aws --version
   ```

2. **Terraform installed** (v1.0+)
   ```bash
   terraform --version
   ```

3. **kubectl installed**
   ```bash
   kubectl version --client
   ```

## Initial Setup

### 1. Configure AWS Profile

Set up your AWS credentials for the terraform-admin user:

```bash
aws configure --profile terraform-admin
```

Then set it as your default profile:

```bash
export AWS_PROFILE=terraform-admin
```

**To make this permanent**, add to your `~/.zshrc` or `~/.bashrc`:
```bash
echo 'export AWS_PROFILE=terraform-admin' >> ~/.zshrc
source ~/.zshrc
```

### 2. Prepare Terraform Variables

Copy the example tfvars file:
```bash
cp example_terraform.tfvars terraform.tfvars
```

Edit `terraform.tfvars` and update:
- `developer_user_arn`: Your IAM user/role ARN for kubectl access
- `aws_region`: Your target AWS region (default: il-central-1)

**Note:** The GitHub Actions role is automatically created by Terraform in `github-oidc.tf`

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Deploy Infrastructure

```bash
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

**Important:** The IAM role for GitHub Actions (`github-oidc-demo-crm`) is created first, then the EKS cluster references it. This prevents authentication issues.

### 5. Configure kubectl Access

After the cluster is created, update your kubeconfig:

```bash
aws eks update-kubeconfig --name demo-crm-eks --region il-central-1 --profile terraform-admin
```

### 6. Verify Access

Test your cluster access:

```bash
kubectl get nodes
kubectl get pods -A
```

## Architecture Overview

### Access Control

The infrastructure implements EKS Access Entries (v1.23+) with the following principals:

1. **Cluster Creator** (automatic): User/role that runs `terraform apply`
2. **Developer User**: Defined in `developer_user_arn` variable
3. **GitHub Actions**: IAM role for CI/CD pipelines

All principals receive `AmazonEKSClusterAdminPolicy` for full cluster access.

### Components

- **github-oidc.tf**: GitHub OIDC provider and IAM role for CI/CD
- **eks.tf**: EKS cluster with managed node groups
- **ecr.tf**: Container registry for application images
- **backend.tf**: S3 + DynamoDB state management

## Troubleshooting

### Error: "User cannot list resource nodes"

**Cause**: Your IAM principal doesn't have cluster access.

**Solution**:
```bash
# Verify your identity
aws sts get-caller-identity --profile terraform-admin

# Check access entries
aws eks list-access-entries --cluster-name demo-crm-eks --region il-central-1

# Add your user if missing (replace with your ARN)
aws eks create-access-entry \
  --cluster-name demo-crm-eks \
  --principal-arn arn:aws:iam::ACCOUNT_ID:user/YOUR_USER \
  --type STANDARD \
  --region il-central-1

# Associate admin policy
aws eks associate-access-policy \
  --cluster-name demo-crm-eks \
  --principal-arn arn:aws:iam::ACCOUNT_ID:user/YOUR_USER \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region il-central-1

# Update kubeconfig
aws eks update-kubeconfig --name demo-crm-eks --region il-central-1
```

### Error: "The specified principalArn is invalid"

**Cause**: Referenced IAM role/user doesn't exist.

**Solution**: Ensure the IAM resource exists before applying EKS configuration. The `depends_on` in `eks.tf` handles this for the GitHub Actions role.

### Error: "state lock" / "ConditionalCheckFailedException"

**Cause**: Previous Terraform operation didn't complete cleanly.

**Solution**:
```bash
# List locks
terraform force-unlock -force LOCK_ID
```

Replace `LOCK_ID` with the ID shown in the error message.

## GitHub Actions Setup

To use the GitHub Actions role in your workflows:

1. Add the role ARN to your repository secrets:
   - Go to repository Settings > Secrets and variables > Actions
   - Add secret: `AWS_ROLE_ARN` with value from `terraform output github_actions_role_arn`

2. In your workflow, configure AWS credentials:
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: il-central-1
```

3. Update the condition in `github-oidc.tf` to restrict to your repository:
```hcl
condition {
  test     = "StringLike"
  variable = "token.actions.githubusercontent.com:sub"
  values   = ["repo:YOUR_ORG/YOUR_REPO:*"]
}
```

## Best Practices

1. **Never use root AWS account** for daily operations
2. **Always set AWS_PROFILE** before running kubectl or terraform
3. **Version control your tfvars** (use git-crypt or similar for sensitive values)
4. **Review access entries** after major infrastructure changes
5. **Use separate profiles** for different environments (dev/staging/prod)

## Maintenance

### Adding New Users

Edit `eks.tf` and add to `access_entries`:

```hcl
new_user = {
  principal_arn = "arn:aws:iam::ACCOUNT_ID:user/username"
  type          = "STANDARD"
  policy_associations = {
    admin = {
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      access_scope = { type = "cluster" }
    }
  }
}
```

Then apply:
```bash
terraform apply -var-file=terraform.tfvars
```

### Updating Kubernetes Version

Edit `eks.tf`:
```hcl
cluster_version = "1.30"  # Update version
```

Then apply with targeted upgrade:
```bash
terraform apply -var-file=terraform.tfvars
```

### Scaling Node Groups

Edit `eks.tf` node group settings:
```hcl
desired_size = 2
max_size     = 3
min_size     = 1
```

## Useful Commands

```bash
# Check cluster status
aws eks describe-cluster --name demo-crm-eks --region il-central-1

# List node groups
aws eks list-nodegroups --cluster-name demo-crm-eks --region il-central-1

# View Terraform outputs
terraform output

# Validate Terraform configuration
terraform validate

# Format Terraform files
terraform fmt -recursive
```

## Resources

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [EKS Access Entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)
