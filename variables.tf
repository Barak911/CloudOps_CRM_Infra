variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "il-central-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "demo-crm-eks"
}

variable "developer_user_arn" {
  description = "IAM User or Role ARN for interactive kubectl access (e.g., barak)"
  type        = string
  default     = "arn:aws:iam::253490775265:user/barak"
}
