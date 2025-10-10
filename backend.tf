terraform {
  backend "s3" {
    bucket         = "<replace-with-bucket-name>"       # e.g. tf-state-demo-crm
    key            = "cloudops_crm/terraform.tfstate"
    region         = "<aws-region>"                      # e.g. us-east-1
    dynamodb_table = "<replace-with-lock-table>"         # e.g. terraform-locks
    encrypt        = true
  }
}
