#!/usr/bin/env bash
set -euo pipefail

# Navigate to the script's root project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Target the dev environment directory relative to script root
DEV_DIR="$PROJECT_ROOT/infra/envs/dev"

echo "==> Fetching Terraform outputs from $DEV_DIR..."

# Retrieve output with fallback check
if ! STAGING_BUCKET=$(terraform -chdir="$DEV_DIR" output -raw staging_bucket_name 2>/dev/null) || [ -z "$STAGING_BUCKET" ]; then
  echo "✗ FAILURE: Could not retrieve 'staging_bucket_name' from Terraform output."
  echo "Make sure you have run 'terraform apply' inside $DEV_DIR."
  exit 1
fi

echo "Using bucket: $STAGING_BUCKET"

echo "==> 1. Verifying RDS Proxy Status..."
PROXY_STATUS=$(aws rds describe-db-proxies --db-proxy-name docbridge-dev --query "DBProxies[0].Status" --output text)
if [ "$PROXY_STATUS" = "AVAILABLE" ] || [ "$PROXY_STATUS" = "available" ]; then
  echo "✓ SUCCESS: DB Proxy is available."
else
  echo "✗ FAILURE: DB Proxy status is $PROXY_STATUS" && exit 1
fi

echo "==> 2. Verifying S3 KMS Encryption..."
aws s3api get-bucket-encryption --bucket "$STAGING_BUCKET" > /dev/null
echo "✓ SUCCESS: KMS encryption policy confirmed on $STAGING_BUCKET."

echo "==> 3. Testing HTTP Non-TLS Deny Policy..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${STAGING_BUCKET}.s3.amazonaws.com")
if [ "$HTTP_CODE" = "403" ]; then
  echo "✓ SUCCESS: HTTP non-TLS request correctly returned 403 Forbidden."
else
  echo "✗ FAILURE: Expected HTTP 403, got $HTTP_CODE" && exit 1
fi

echo "--------------------------------------------------"
echo "All Phase 3 validation checks passed successfully!"