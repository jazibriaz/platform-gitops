#!/usr/bin/env bash
# One-time: create the S3 bucket that stores Terraform state.
# Chicken-and-egg: Terraform can't store its state in a bucket that Terraform itself
# hasn't created yet, so this one bucket is made with the CLI.
set -euo pipefail

REGION="${REGION:-eu-west-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="pcforge-tfstate-${ACCOUNT_ID}"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket $BUCKET already exists, nothing to do."
  exit 0
fi

aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

# Versioning: every state write keeps the previous version, so a bad apply is recoverable
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

# Encryption at rest (state can contain sensitive values)
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Never public
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Created $BUCKET in $REGION"
