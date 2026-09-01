# M0 Validation Runbook

Acceptance criteria checklist for Milestone 0. This document reflects the current repo state, so the checklist intentionally uses FAIL and TODO rows instead of claiming sign-off.

## Repo Reality

- A `package-lock.json` is present, so `npm ci` is reproducible.
- The root workspace now exposes a real `typecheck` script.
- `npm test` now fails when underlying workspace tests fail.
- Five workflows exist in `.github/workflows`: `ci-shared.yml`, `aws-test.yml`, `gitleaks.yml`, `infra.yml`, and `service-images.yml`.
- The full CI/CD matrix described in the earlier milestone notes is not present yet.

## Phase 1 — Static Checks (No AWS, No Docker)

| # | Action / Command | Expected Pass Criterion | Status |
|---|---|---|---|
| 1.1 | `npm ci` | Clean install from a committed lockfile | PASS |
| 1.2 | `npm run typecheck` | TypeScript checks run from the repo root | PASS |
| 1.3 | `npm run lint` | Root ESLint config and lint script are present | PASS |
| 1.4 | `npm test` | Workspace test failures fail the command | PASS |
| 1.5 | `npm run build --workspaces --if-present` | Workspace builds complete without manual intervention | TODO |
| 1.6 | `terraform fmt -check -recursive infra/` | Formatting is enforced across all `.tf` files | TODO |
| 1.7 | `terraform validate` in `dev` and `prod` | Both environments validate cleanly | FAIL |
| 1.8 | `gitleaks detect --source . --no-banner` | Secret scan runs and fails on leaks | FAIL |

## Phase 2 — Local Integration (Docker Required)

| # | Action / Command | Expected Pass Criterion | Status |
|---|---|---|---|
| 2.1 | `cp .env.example .env` | Local defaults are bootstrapped into `.env` | TODO |
| 2.2 | `docker compose up --build -d` | Backing services and APIs start cleanly | TODO |
| 2.3 | `./scripts/smoke-local.sh` | Any failed check fails the script exit code | PASS |
| 2.4 | `docker compose down -v` | Containers and volumes are removed cleanly | TODO |

## Phase 3 — AWS Dev Infrastructure Verification

| # | Action / Command | Expected Pass Criterion | Status |
|---|---|---|---|
| 3.1 | `cd infra/envs/dev && terraform plan` | `No changes.` indicates zero drift | TODO |
| 3.2 | Check RDS instance status | `PubliclyAccessible: false`, `StorageEncrypted: true`, `Status: available` | TODO |
| 3.3 | Check RDS Proxy status | `Status: available`, `RequireTLS: true` | TODO |
| 3.4 | Check RDS Proxy target health | `TargetHealth.State: AVAILABLE` | TODO |
| 3.5 | Check S3 staging bucket encryption | SSE-KMS is enabled on the bucket | TODO |
| 3.6 | Check S3 public access block | All four block flags are `true` | TODO |
| 3.7 | Check S3 bucket lifecycle rules | Expiration and multipart cleanup policies are active | TODO |
| 3.8 | Test S3 transport security | HTTPS works and HTTP is denied | TODO |
| 3.9 | Check CloudFront SPA distribution | HTTPS endpoint is available | TODO |
| 3.10 | Check Secrets Manager | DB and service credentials exist under `/docbridge/dev/db/*` | TODO |

## Phase 4 — GitHub Actions CI/CD Verification

| # | Check / Workflow | Expected Pass Criterion | Status |
|---|---|---|---|
| 4.1 | GitHub workflow coverage | The repo has the workflow surface needed for the milestone | PASS |
| 4.2 | `gitleaks` workflow | Secret scanning is present as a workflow | PASS |
| 4.3 | `service-*` workflows | Service images are built and pushed on `main` | PASS |
| 4.4 | `infra` workflow | Terraform validation and apply jobs exist | PASS |

## Phase 5 — Automated Teardown & Cost Verification

| # | Action / Command | Expected Pass Criterion | Status |
|---|---|---|---|
| 5.1 | `./scripts/destroy.sh` | Dev stack resources are destroyed cleanly | TODO |
| 5.2 | `./scripts/check_cleanup.sh` | No lingering billable AWS resources remain | TODO |
| 5.3 | Final cost check | The account has no active M0 hourly or monthly charges | TODO |

## Sign-Off Log

| Milestone | Execution Date | Target Commit | Result |
|---|---|---|---|
| **M0 — Foundations** | Not signed off | Current branch state | **BLOCKED: checklist contains FAIL and TODO items** |
