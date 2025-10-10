variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "il-center-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "demo-crm-eks"
}
