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
