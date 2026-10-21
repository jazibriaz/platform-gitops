provider "aws" {
  region = var.region

  # Every resource that supports tags gets these automatically
  default_tags {
    tags = {
      Project   = "pcforge"
      ManagedBy = "terraform"
      Repo      = "platform-gitops"
    }
  }
}

# Lets us look up the account ID and region without hardcoding them
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}
