# Troubleshooting Guide

## EKS `kubectl` Access Issues

### Problem: "The server has asked for the client to provide credentials"

If `kubectl get nodes` returns:
```
The server has asked for the client to provide credentials
```

This means your IAM identity doesn't have an access entry on the EKS cluster.

### Solution: Create EKS Access Entry

1. **Get your IAM principal ARN and create access entry:**

```bash
# Set variables
AWS_REGION=us-east-1
CLUSTER_NAME=develeap-eks-cluster

# Get your current IAM identity ARN
PRINCIPAL_ARN=$(aws sts get-caller-identity --query Arn --output text)

# Create access entry for your IAM identity
aws eks create-access-entry \
  --cluster-name $CLUSTER_NAME \
  --region $AWS_REGION \
  --principal-arn $PRINCIPAL_ARN
```

2. **Associate cluster admin policy:**

```bash
# Grant cluster admin permissions
aws eks associate-access-policy \
  --cluster-name $CLUSTER_NAME \
  --region $AWS_REGION \
  --principal-arn $PRINCIPAL_ARN \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

Both commands should return status information showing the access entry and policy association.

3. **Update kubeconfig and verify:**

```bash
# Update local kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

# Verify access
kubectl get nodes
```

You should now see your EKS nodes listed.

### Granting Access to Additional IAM Users

To grant access to other team members:

```bash
# Get the other user's ARN
OTHER_USER_ARN="arn:aws:iam::ACCOUNT_ID:user/USERNAME"

# Create access entry
aws eks create-access-entry \
  --cluster-name $CLUSTER_NAME \
  --region $AWS_REGION \
  --principal-arn $OTHER_USER_ARN

# Associate policy
aws eks associate-access-policy \
  --cluster-name $CLUSTER_NAME \
  --region $AWS_REGION \
  --principal-arn $OTHER_USER_ARN \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

---

## Port Conflicts (Local Development)

### Problem: Port 5000 already in use

On macOS, port 5000 is often used by ControlCenter (AirPlay Receiver).

### Solution: Use port 5001 for local development

The docker-compose files in this project use port 5001:5000 mapping to avoid conflicts:

```yaml
ports:
  - "5001:5000"  # External:Internal
```

Access the API at `http://localhost:5001` instead of `http://localhost:5000`.

---

## Docker Build Issues

### Problem: "externally-managed-environment" error

When running `pip install` on macOS, you may encounter:
```
error: externally-managed-environment
```

### Solution: Use virtual environment

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

---

## Terraform Module Issues

### Problem: Develeap Terraform module not found

The original project references a private Develeap EKS module that may not be publicly available.

### Solution: Use official AWS EKS module

This project uses the official Terraform AWS EKS module:

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  # ...
}
```

This is production-ready, well-maintained, and publicly available.

---

## ECR Authentication

### Problem: Docker push fails with authentication error

### Solution: Authenticate Docker with ECR

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  253490775265.dkr.ecr.us-east-1.amazonaws.com
```

---

## GitHub Actions CI/CD Issues

### Problem: GitHub Actions workflow fails with "eks:DescribeCluster" AccessDeniedException

If the GitHub Actions workflow fails with:
```
An error occurred (AccessDeniedException) when calling the DescribeCluster operation:
User: arn:aws:sts::ACCOUNT_ID:assumed-role/github-actions-ecr-eks/GitHubActions is not
authorized to perform: eks:DescribeCluster
```

This means the GitHub Actions IAM role needs additional permissions.

### Solution: Configure GitHub Actions IAM Role

The GitHub Actions IAM role requires two types of access:

#### 1. IAM Policy for EKS API Access

The role needs an IAM policy with `eks:DescribeCluster` permission:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": [
        "arn:aws:eks:us-east-1:ACCOUNT_ID:cluster/develeap-eks-cluster"
      ]
    }
  ]
}
```

**Apply the policy:**
```bash
# Update the existing policy
aws iam create-policy-version \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/GitHubActionsEcrEksPolicy \
  --policy-document file://policy.json \
  --set-as-default
```

#### 2. EKS Access Entry for Kubernetes RBAC

The role also needs an EKS access entry to interact with Kubernetes:

```bash
# Create access entry for GitHub Actions role
aws eks create-access-entry \
  --cluster-name develeap-eks-cluster \
  --region us-east-1 \
  --principal-arn arn:aws:iam::ACCOUNT_ID:role/github-actions-ecr-eks

# Associate cluster admin policy
aws eks associate-access-policy \
  --cluster-name develeap-eks-cluster \
  --region us-east-1 \
  --principal-arn arn:aws:iam::ACCOUNT_ID:role/github-actions-ecr-eks \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

### GitHub Secrets Configuration

Ensure these secrets are configured in your GitHub repository at **Settings → Secrets and variables → Actions**:

- `AWS_ROLE_ARN`: The ARN of the GitHub Actions IAM role (e.g., `arn:aws:iam::ACCOUNT_ID:role/github-actions-ecr-eks`)

The workflow uses OIDC (OpenID Connect) to assume this role, which is more secure than using long-lived access keys.

---

## Cost Management

### Remember to destroy resources!

After testing, always run:

```bash
cd infrastructure
terraform destroy
```

This prevents unexpected AWS charges. EKS clusters and NAT gateways incur hourly charges.

---

## Getting Help

If you encounter issues not covered here:

1. Check AWS CloudWatch logs for EKS cluster issues
2. Use `kubectl describe` for Kubernetes resource issues
3. Review Terraform state with `terraform show`
4. Check AWS Console for resource status
