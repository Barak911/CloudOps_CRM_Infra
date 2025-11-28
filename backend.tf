terraform {
  backend "s3" {
    bucket         = "tf-state-demo-crm"
    key            = "cloudops_crm/terraform.tfstate"
    region         = "il-central-1" # ← correct region where the bucket is located
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
