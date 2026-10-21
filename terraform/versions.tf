terraform {
  required_version = ">= 1.10" # 1.10+ needed for S3-native state locking (use_lockfile)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.59" # the EKS module v21 needs >= 6.59
    }
  }
}
