module "eks" {
  source  = "github.com/develeap/terraform-aws-eks-external"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"
  region          = var.aws_region

  # minimal node group
  node_groups = {
    default = {
      desired_capacity = 1
      max_capacity     = 1
      min_capacity     = 1
      instance_types   = ["t3a.medium"]
      capacity_type    = "SPOT"
    }
  }

  tags = {
    project = "CloudOps_CRM"
  }
}
