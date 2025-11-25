resource "aws_ecr_repository" "demo_crm" {
  name                 = "demo-crm"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    project = "CloudOps_CRM"
  }
}
