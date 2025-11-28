data "aws_vpc" "default" { default = true }

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  # Exclude us-east-1e which is not supported by EKS
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  # expose API publicly so kubectl works outside VPC
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    default = {
      desired_size   = 1
      max_size       = 1
      min_size       = 1
      instance_types = ["t3a.medium"]
      capacity_type  = "SPOT"
    }
  }

  tags = { project = "CloudOps_CRM" }

  # Enable cluster access management
  enable_cluster_creator_admin_permissions = false

  # Grant access to additional IAM principals
  access_entries = {
    # GitHub Actions role - now created in github-oidc.tf
    github_actions = {
      principal_arn = aws_iam_role.github_actions.arn
      type          = "STANDARD"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    # Developer user access
    developer = {
      principal_arn = var.developer_user_arn
      type          = "STANDARD"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Ensure IAM role is created before cluster access entries
  depends_on = [aws_iam_role.github_actions]
}