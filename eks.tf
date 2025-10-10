# eks.tf
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"          # latest major

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  # Minimal managed node group
  eks_managed_node_groups = {
    default = {
      desired_size   = 1
      max_size       = 1
      min_size       = 1
      instance_types = ["t3a.medium"]
      capacity_type  = "SPOT"
    }
  }

  tags = {
    project = "CloudOps_CRM"
  }
}