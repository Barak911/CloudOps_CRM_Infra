terraform {
  backend "s3" {
    bucket         = "tf-state-demo-crm"            # ← your S3 bucket
    key            = "cloudops_crm/terraform.tfstate"
    region         = "us-east-1"                    # ← hard-coded region
    dynamodb_table = "terraform-locks"              # ← your DynamoDB lock table
    encrypt        = true
  }
}
