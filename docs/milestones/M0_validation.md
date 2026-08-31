# M0 Validation Runbook

Acceptance criteria checklist for Milestone 0. All phases must pass to complete M0 sign-off.

---

## Phase 1 — Static Checks (No AWS, No Docker)

| # | Action / Command | Expected Pass Criterion | Status |
|---|---|---|---|
| 1.1 | `npm ci` | Clean install, exits 0 | PASS |
| 1.2 | `npm run typecheck` | No TypeScript errors | PASS |
| 1.3 | `npm run lint` | Linter exits 0 | PASS |
| 1.4 | `npm test` | All unit tests pass across workspaces | PASS |
| 1.5 | `npm run build --workspaces --if-present` | Bundles build successfully via esbuild | PASS |
| 1.6 | `terraform fmt -check -recursive infra/` | Formatting verified across all `.tf` files | PASS |
| 1.7 | `terraform validate` (`global`, `dev`, `prod`) | `Success!` for all 3 environments | PASS |
| 1.8 | `gitleaks detect --source . --no-banner` | No leaked credentials detected | PASS |

---

## Phase 2 — Local Integration (Docker Required)

| # | Action / Command | Expected Pass Criterion | Status |
|---|---|---|---|
| 2.1 | `cp .env.example .env` | `.env` file created | PASS |
| 2.2 | `docker compose up --build -d` | Containers for `auth`, `platform`, `docbridge-api`, `postgres`, `localstack` start | PASS |
| 2.3 | `./scripts/smoke-local.sh` | All microservice `/health` endpoints return 200; DB isolation holds; LocalStack queues and bucket exist | PASS |
| 2.4 | `docker compose down -v` | Containers and volumes cleanly stopped | PASS |

---

## Phase 3 — AWS Dev Infrastructure Verification

| # | Action / Command | Expected Pass Criterion | Status |
|---|---|---|---|
| 3.1 | `cd infra/envs/dev && terraform plan` | `No changes.` (zero state drift) | PASS |
| 3.2 | Check RDS Instance status | `PubliclyAccessible: false`, `StorageEncrypted: true`, `Status: available` | PASS |
| 3.3 | Check RDS Proxy status | `Status: available`, `RequireTLS: true` | PASS |
| 3.4 | Check RDS Proxy Target Health | `TargetHealth.State: AVAILABLE` | PASS |
| 3.5 | Check S3 Staging Bucket Encryption | SSE Algorithm is `aws:kms` with Customer Key | PASS |
| 3.6 | Check S3 Public Access Block | All 4 block flags set to `true` | PASS |
| 3.7 | Check S3 Bucket Lifecycle Rules | 30-day expiration and 7-day abort incomplete multipart uploads active | PASS |
| 3.8 | Test S3 Transport Security | Authenticated HTTPS `aws s3 ls` succeeds; authenticated HTTP `aws s3 ls` receives explicit policy deny | PASS |
| 3.9 | Check CloudFront SPA Distribution | Responds via HTTPS (403 expected prior to SPA artifact deployment) | PASS |
| 3.10 | Check Secrets Manager | DB master and service credentials generated under `/docbridge/dev/db/*` | PASS |

---

## Phase 4 — GitHub Actions CI/CD Verification

| # | Check / Workflow | Expected Pass Criterion | Status |
|---|---|---|---|
| 4.1 | GitHub Workflow Runs | All workflows pass on `main` branch | PASS |
| 4.2 | `gitleaks` Workflow | Scan passes with no secrets flagged | PASS |
| 4.3 | `service-*` Workflows | Builds and pushes Docker images tagged with Git commit SHA to ECR | PASS |
| 4.4 | `infra` Workflow | `validate` and `apply-dev` steps complete successfully | PASS |

---

## Phase 5 — Automated Teardown & Cost Verification

| # | Action / Command | Expected Pass Criterion | Status |
|---|---|---|---|
| 5.1 | `./scripts/destroy.sh` | `terraform destroy` successfully removes dev stack resources | PASS |
| 5.2 | `./scripts/check_cleanup.sh` | Confirms 0 active NAT Gateways, 0 RDS instances, 0 RDS proxies, 0 unattached EIPs, 0 project secrets, 0 customer KMS keys, and 0 CloudFront distributions | PASS |
| 5.3 | Final Cost Check | All billable hourly/monthly resources confirmed removed | PASS |

---

## Sign-Off Log

| Milestone | Execution Date | Target Commit | Result |
|---|---|---|---|
| **M0 — Foundations** | August 30, 2026 | `d5d05a4+` | **PASSED (ALL PHASES VERIFIED)** |
