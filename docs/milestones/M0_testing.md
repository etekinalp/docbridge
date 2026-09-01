# M0 Testing — Foundations

This is the runbook for the repo as it exists today. It separates what is implemented from what is still missing, because several of the milestone checks are documented before the repo can actually enforce them.

## Current Repo Facts

- The root `package.json` defines `build`, `test`, `typecheck`, `lint`, `dev:infra`, and `dev:infra:down`.
- A `package-lock.json` is now present, so `npm ci` is a valid install path.
- The root `package.json` now exposes a real `typecheck` script that fans out to workspace typechecks.
- `npm test` no longer masks failures with `|| exit 0`.
- `scripts/smoke-local.sh` now exits non-zero when any check fails.
- Only two GitHub workflows exist today: `ci-shared.yml` and `aws-test.yml`.

## 1. Local Verification

### Prerequisites

- Node.js >= 22
- Docker Desktop or OrbStack
- Terraform >= 1.15.8
- AWS CLI v2

### Validation Matrix

| # | Check | Current Repo Status | Notes |
|---|---|---|---|
| 1.1 | `npm ci` | PASS | The repo now installs cleanly from the checked-in lockfile. |
| 1.2 | `npm run typecheck` | PASS | The root workspace now fans out to workspace typechecks. |
| 1.3 | `npm run lint` | PASS | The repo now has a root ESLint config and lint script. |
| 1.4 | `npm test` | PASS | The command now fails when a workspace test fails. |
| 1.5 | `npm run build --workspaces --if-present` | TODO | Build wiring exists, but this milestone has not verified it end-to-end. |
| 1.6 | `cp .env.example .env` | TODO | The template exists, but this runbook still needs to be exercised against the checked-in defaults. |
| 1.7 | `docker compose up --build -d` | TODO | Compose exists, but this doc does not yet claim a verified local boot path. |
| 1.8 | `docker compose ps` | TODO | Container health reporting still needs to be tied to a non-masked smoke check. |
| 1.9 | `./scripts/smoke-local.sh` | PASS | The script now exits non-zero when any check fails. |

### Smoke Test Expectations

The current smoke script now fails the process when any dependency is unavailable. It checks LocalStack, PostgreSQL, and the service ports, and it is a real gate rather than an informational log.

### Optional Worker Check

If the worker pipeline is running locally, dispatch a test message through LocalStack SQS and confirm the fan-out worker logs it. This remains a TODO until the worker entrypoint and queue wiring are treated as a gated check.

## 2. Deploy to AWS Dev

### Account Prerequisites

- Set up an AWS billing alarm before provisioning anything persistent.
- Configure AWS CLI credentials for us-east-1 admin access.

### State Backend

```bash
./infra/bootstrap/create-state-backend.sh
```

Copy the output into `infra/envs/{global,dev,prod}/backend.hcl`.

### GitHub OIDC

The repo has an OIDC test workflow, but the full deployment-role flow described in the milestone still needs to be completed and verified against the actual Terraform and workflow stack.

### Provisioning Status

| # | Step | Current Repo Status | Notes |
|---|---|---|---|
| 2.1 | `cd infra/envs/global && terraform apply` | TODO | Global resources are described, but this runbook does not yet prove the full bootstrap path. |
| 2.2 | `cd infra/envs/dev && terraform apply` | TODO | Dev infrastructure exists in Terraform, but it should be revalidated from the real repo state. |
| 2.3 | `cd infra/envs/prod && terraform validate` | FAIL | The prod environment is not yet a complete working stack. |

## 3. Live AWS Checks

| # | Check | Current Repo Status | Notes |
|---|---|---|---|
| 3.1 | `terraform plan` in `infra/envs/dev` | TODO | Drift validation should be rerun before any long pause in the work. |
| 3.2 | RDS instance status | TODO | The infra ADRs describe the target state, but the doc should only mark this as verified after a live check. |
| 3.3 | RDS Proxy status | TODO | Same as above. |
| 3.4 | S3 staging bucket encryption and public access block | TODO | Same as above. |
| 3.5 | CloudFront distribution | TODO | Same as above. |
| 3.6 | Secrets Manager material | TODO | Same as above. |

## 4. Teardown

```bash
./scripts/destroy.sh
./scripts/check_cleanup.sh
```

`check_cleanup.sh` is the right guard to run whenever the work pauses for a while, because it is the best existing check for making sure no billable AWS resources are left behind.