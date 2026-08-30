#!/usr/bin/env bash
set -e

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
BUCKET_NAME="docbridge-tf-state-${ACCOUNT_ID}"
TABLE_NAME="docbridge-tf-locks"

echo "Creating S3 bucket for Terraform state: ${BUCKET_NAME}..."
aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${REGION}"

echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

echo "Enabling server-side encryption..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms"
      }
    }]
  }'

echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "Creating DynamoDB table for lock management: ${TABLE_NAME}..."
aws dynamodb create-table \
  --table-name "${TABLE_NAME}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}" || true

echo ""
echo "===================================================="
echo "Backend state storage created successfully!"
echo "Bucket: ${BUCKET_NAME}"
echo "DynamoDB Table: ${TABLE_NAME}"
echo "===================================================="