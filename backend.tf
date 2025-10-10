terraform {
  backend "s3" {
    bucket         = "tf-state-demo-crm"
    key            = "cloudops_crm/terraform.tfstate"
    region         = "il-central-1"   # ← correct region
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
