#!/usr/bin/env bash
set -euo pipefail

echo "==> Verifying AWS resource teardown..."
CLEAN=true

echo "==> 1. Checking active NAT Gateways..."
NAT_GW=$(aws ec2 describe-nat-gateways --query "NatGateways[?State!='deleted'].NatGatewayId" --output text)
if [ -n "$NAT_GW" ]; then
  echo "✗ WARNING: Active NAT Gateway(s) found: $NAT_GW"
  CLEAN=false
else
  echo "✓ SUCCESS: 0 active NAT Gateways."
fi

echo "==> 2. Checking active RDS DB Instances..."
RDS_INST=$(aws rds describe-db-instances --query "DBInstances[*].DBInstanceIdentifier" --output text)
if [ -n "$RDS_INST" ]; then
  echo "✗ WARNING: Active RDS Instance(s) found: $RDS_INST"
  CLEAN=false
else
  echo "✓ SUCCESS: 0 active RDS DB Instances."
fi

echo "==> 3. Checking active RDS Proxies..."
RDS_PROXY=$(aws rds describe-db-proxies --query "DBProxies[*].DBProxyName" --output text)
if [ -n "$RDS_PROXY" ]; then
  echo "✗ WARNING: Active RDS Proxy(ies) found: $RDS_PROXY"
  CLEAN=false
else
  echo "✓ SUCCESS: 0 active RDS Proxies."
fi

echo "==> 4. Checking Elastic IPs..."
EIPS=$(aws ec2 describe-addresses --query "Addresses[*].AllocationId" --output text)
if [ -n "$EIPS" ]; then
  echo "✗ WARNING: Elastic IP(s) found: $EIPS"
  CLEAN=false
else
  echo "✓ SUCCESS: 0 Elastic IPs found."
fi

echo "==> 5. Checking Secrets Manager Secrets..."
SECRETS=$(aws secretsmanager list-secrets --query "SecretList[?contains(Name, 'docbridge')].Name" --output text)
if [ -n "$SECRETS" ]; then
  echo "✗ WARNING: Active secret(s) found: $SECRETS"
  CLEAN=false
else
  echo "✓ SUCCESS: 0 project secrets found."
fi

echo "==> 6. Checking KMS Customer Managed Keys..."
KMS_KEYS=$(aws kms list-keys --query "Keys[*].KeyId" --output text)
ACTIVE_KEYS=""
for KEY in $KMS_KEYS; do
  MANAGER=$(aws kms describe-key --key-id "$KEY" --query "KeyMetadata.KeyManager" --output text 2>/dev/null || true)
  STATE=$(aws kms describe-key --key-id "$KEY" --query "KeyMetadata.KeyState" --output text 2>/dev/null || true)
  
  if [ "$MANAGER" = "CUSTOMER" ] && [ "$STATE" = "Enabled" ]; then
    ACTIVE_KEYS="$ACTIVE_KEYS $KEY"
  fi
done

if [ -n "$ACTIVE_KEYS" ]; then
  echo "✗ WARNING: Active Customer KMS Key(s) found:$ACTIVE_KEYS"
  CLEAN=false
else
  echo "✓ SUCCESS: 0 active Customer KMS Keys found."
fi

echo "==> 7. Checking CloudFront Distributions..."
CF_DISTS=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='docbridge-dev' || Origins.Items[?contains(DomainName, 'docbridge')]].Id" --output text 2>/dev/null || true)
if [ -n "$CF_DISTS" ] && [ "$CF_DISTS" != "None" ]; then
  echo "✗ WARNING: Active CloudFront distribution(s) found: $CF_DISTS"
  CLEAN=false
else
  echo "✓ SUCCESS: 0 active CloudFront distributions found."
fi

echo "--------------------------------------------------"
if [ "$CLEAN" = true ]; then
  echo "✓ ALL CLEAN: No billable active resources detected!"
else
  echo "✗ ACTION REQUIRED: Residual billable resources detected above."
  exit 1
fi