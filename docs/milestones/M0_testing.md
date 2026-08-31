# M0 Testing — Foundations

**Milestone claim:** Local environment runs via Docker Compose, Terraform provisions the dev foundations, and CI pipelines pass cleanly on `main`.

---

## 1. Local Verification

### Prerequisites
- Node.js ≥ 22
- Docker Desktop or OrbStack
- Terraform ≥ 1.15.8
- AWS CLI v2

### Execution Steps

1. **Install Dependencies & Static Quality Checks:**
   ```bash
   npm ci
   npm run typecheck && npm run lint && npm test
   ```

    Expected outcome: All workspaces pass typecheck, linting, and 24+ unit tests across 8 test files.

### Environment Configuration:

```Bash
cp .env.example .env
Spin Up Local Infrastructure:
```

```Bash
docker compose up --build -d
Verify Container Status:
```

```Bash
docker compose ps
Expected outcome: All containers report healthy.
```

### Run Integration Smoke Tests:

``` Bash
./scripts/smoke-local.sh
Expected Smoke Output (Every Line PASS)
auth | platform | docbridge-api /health — All three microservice containers respond.

... /health/ready — Each service connects to its dedicated logical database using isolated credentials.

auth_svc denied on platform db — Confirms cross-service database access is blocked by construction (ADR-009).

staging bucket exists + 4 queue ... exists lines — LocalStack mirrors AWS infrastructure topology (ADR-005/008).
```

#### Optional: Test Worker Event Consumption

```Bash
# Terminal 1: Run worker fanout process
JOB_QUEUE_URL=http://localhost:4566/000000000000/docbridge-job-queue \
AWS_ENDPOINT_URL=http://localhost:4566 AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test \
npm run dev -w @docbridge/worker-fanout

# Terminal 2: Dispatch test message via LocalStack SQS
docker compose exec localstack awslocal sqs send-message \
  --queue-url http://localhost:4566/000000000000/docbridge-job-queue \
  --message-body '{"jobId":"smoke-test"}'
```

Expected log in Terminal 1: fanout stub received job message.


### Local Teardown
```Bash
docker compose down -v
2. Deploy to AWS (dev) — Setup Runbook
2.1 Account Prerequisites
Set up an AWS Billing Alarm (e.g., $50/month threshold in AWS Budgets).
```

Configure AWS CLI credentials for us-east-1 admin access (aws configure or SSO).

### Sanity check:

```Bash
aws sts get-caller-identity
2.2 Remote State Backend (ADR-012)
Bash
./infra/bootstrap/create-state-backend.sh
Copy printed values into infra/envs/{global,dev,prod}/backend.hcl.
```

### 2.3 GitHub OIDC Role Setup
Create or update the GitHub Actions deployment role (docbridge-github-deploy) with explicit trust conditions (repo:DeveloperMastery/docbridge:* and aud: sts.amazonaws.com).

### 2.4 GitHub Repository Secrets & Variables
Add under Settings → Secrets and variables → Actions → Variables:

```AWS_DEPLOY_ROLE_ARN = arn:aws:iam::<ACCOUNT_ID>:role/docbridge-github-deploy

AWS_REGION = us-east-1

TF_STATE_BUCKET = <from-bootstrap-step>

Create Environments:

dev (unprotected)

prod (requires manual reviewer approval)
```

### 2.5 Provision Environment

```Bash
# Global resources (ECR repos)
cd infra/envs/global
terraform init -backend-config=backend.hcl && terraform apply

# Dev environment (VPC, RDS, RDS Proxy, KMS, S3, CloudFront)
cd ../dev
terraform init -backend-config=backend.hcl && terraform apply
```

### 3. Verify Live AWS Infrastructure

```Bash
cd infra/envs/dev

# 1. State Drift Check
terraform plan   # Expect: "No changes."

# 2. View Active Outputs
terraform output

# 3. RDS Security Check
aws rds describe-db-instances --db-instance-identifier docbridge-dev \
  --query 'DBInstances[0].{Public:PubliclyAccessible,Encrypted:StorageEncrypted,Status:DBInstanceStatus}'
# Expect: Public=false, Encrypted=true, Status=available

# 4. RDS Proxy Target Health Check
aws rds describe-db-proxy-targets --db-proxy-name docbridge-dev \
  --query 'Targets[0].TargetHealth.State'
# Expect: "AVAILABLE"

# 5. S3 Staging Bucket Security & Lifecycle
BUCKET=$(terraform output -raw staging_bucket_name)
aws s3api get-bucket-encryption --bucket "$BUCKET"
aws s3api get-public-access-block --bucket "$BUCKET"
aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET"

# 6. Authenticated TLS-Only Transport Policy Check
aws s3 ls "s3://${BUCKET}"                                # Succeeds over HTTPS
aws s3 ls "s3://${BUCKET}" --endpoint-url [http://s3.amazonaws.com](http://s3.amazonaws.com)  # Fails with explicit deny
4. Environment Teardown
To eliminate recurring charges between development sessions:
```

```Bash
./scripts/destroy.sh            # Destroys dev environment resources
./scripts/check_cleanup.sh      # Audits AWS account across 7 categories to confirm zero charges
```