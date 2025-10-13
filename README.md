# Infrastructure Repository

This repository contains **Terraform** code for provisioning cloud infrastructure required by the project.

Stack:
* AWS VPC, subnets, IAM roles
* EKS cluster via develeap external module
* Amazon ECR repository for Docker images

Usage:
```bash
terraform init
terraform plan
terraform apply
```

---

> Terraform state backend: S3 + DynamoDB (configure separately).

## Cluster access provisioning

Terraform now creates EKS Access Entries that automatically grant **cluster-admin** permissions to:

1. The GitHub Actions OIDC role (passed via `github_actions_role_arn`)
2. Your interactive IAM identity (passed via `developer_user_arn`)

Add these two ARNs in `terraform.tfvars` before `terraform apply`:

```hcl
github_actions_role_arn = "arn:aws:iam::<ACCOUNT_ID>:role/github-oidc-demo-crm"
developer_user_arn      = "arn:aws:iam::<ACCOUNT_ID>:user/barak"
```

After the apply finishes you can immediately run:

```bash
aws eks update-kubeconfig --name demo-crm-eks --region il-central-1 --profile barak
kubectl get nodes  # should succeed without additional mapping steps
```

## Gaining kubectl access

After Terraform creates the EKS cluster, you must grant your IAM user access.

### 1. Using modern EKS Access Entry (recommended)
```
AWS_REGION=il-central-1
CLUSTER=demo-crm-eks
PROFILE=terraform-admin   # profile that created the cluster (has admin)

PRINCIPAL_ARN=$(aws sts get-caller-identity --profile $PROFILE --query Arn --output text)

aws eks create-access-entry \
  --cluster-name $CLUSTER \
  --region $AWS_REGION \
  --principal-arn $PRINCIPAL_ARN \
  --profile $PROFILE

aws eks associate-access-policy \
  --cluster-name $CLUSTER \
  --region $AWS_REGION \
  --principal-arn $PRINCIPAL_ARN \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --profile $PROFILE
```
### 2. Classic aws-auth ConfigMap (alternative)
```
# from any profile already mapped (e.g. terraform-admin)
kubectl edit -n kube-system configmap/aws-auth

# then add
mapUsers: |
  - userarn: arn:aws:iam::<ACCOUNT_ID>:user/barak
    username: barak
    groups:
      - system:masters
```
Either method gives your IAM identity full administrator access to the cluster so subsequent `kubectl` calls and CI deployments succeed.
