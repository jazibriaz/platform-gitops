# Where Terraform keeps its state file (the record of what it has created).
# The bucket name is passed at init time, because backend blocks can't use variables:
#   terraform init -backend-config="bucket=pcforge-tfstate-<ACCOUNT_ID>"
terraform {
  backend "s3" {
    key          = "platform/eks/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true # writes a .tflock object next to the state; no DynamoDB table needed
  }
}
