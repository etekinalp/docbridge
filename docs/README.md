# DocBridge Documentation Workspace


# 🌉 DocBridge

> Enterprise-grade, cloud-native document distribution and orchestration platform built on a modern TypeScript monorepo architecture.

[![Shared CI](https://github.com/etekinalp/docbridge/actions/workflows/ci-shared.yml/badge.svg)](https://github.com/etekinalp/docbridge/actions/workflows/ci-shared.yml)
[![AWS OIDC Test](https://github.com/etekinalp/docbridge/actions/workflows/aws-test.yml/badge.svg)](https://github.com/etekinalp/docbridge/actions/workflows/aws-test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node Version](https://img.shields.io/badge/node-%3E%3D22-blue.svg)](https://nodejs.org)
[![Terraform Version](https://img.shields.io/badge/terraform-%3E%3D1.15.8-purple.svg)](https://www.terraform.io)

---

## 🎯 Overview

**DocBridge** is a high-throughput, secure platform designed to ingest, process, transform, and distribute complex multi-format documentation pipelines at scale. Built using an event-driven architecture on AWS, DocBridge provides a unified React single-page application (SPA) frontend backed by robust Node.js microservices and serverless workers.

---

## 🏗️ Architecture & Tech Stack

* **Monorepo Management:** `npm workspaces` with shared TypeScript packages.
* **Frontend:** React SPA, Vite, Tailwind CSS.
* **Backend Services:** Node.js, TypeScript (Auth API, DocBridge Core API, Document Platform Service).
* **Workers:** AWS Lambda (Fan-out worker, Delivery worker) triggered via SQS.
* **Infrastructure as Code (IaC):** Terraform (`modules/` + `envs/{dev,prod}`) with remote S3 backend & DynamoDB state locking.
* **CI/CD:** GitHub Actions with OIDC AWS authentication (zero long-lived cloud credentials).
* **Local Emulation:** Docker Compose, LocalStack (S3, SQS), and local PostgreSQL 16.

---

## 🤖 Workflows

These are the GitHub Actions workflows currently in the repo and what each one does:

* **`ci-shared.yml`** - Runs the main code quality gate on `main` and pull requests: installs dependencies, runs typecheck, lint, tests, and build.
* **`aws-test.yml`** - Manually verifies AWS OIDC access from GitHub Actions by assuming the deployment role and calling `sts get-caller-identity`.
* **`gitleaks.yml`** - Scans the repository for secrets and hardcoded credentials on pushes, pull requests, and manual runs.
* **`infra.yml`** - Validates Terraform formatting and configuration for `infra/envs/global`, `infra/envs/dev`, and `infra/envs/prod`, and can manually apply the dev stack when requested.
* **`service-images.yml`** - Builds the three service Docker images on pull requests, and on `main` it authenticates to AWS ECR and pushes versioned images for `user-api`, `platform-api`, and `docbridge-api`.

---

## 🚀 Quick Start (Local Development)

### 1. Prerequisites
Ensure your local machine has the following installed:
* **Node.js** $\ge 22$
* **Docker & Docker Compose** (Colima or Docker Desktop)
* **AWS CLI** & **Terraform** $\ge 1.15.8$

### 2. Environment Setup
```bash
# Clone the repository and copy environment defaults
cp .env.example .env

# Install monorepo dependencies
npm ci
```

### 3. Spin Up Local Infrastructure
Launch PostgreSQL and LocalStack (AWS S3/SQS emulation):

```Bash
docker compose up --build -d
4. Run Local Smoke Tests
Verify that your backing services and local emulators are fully responsive:
```

```Bash
./scripts/smoke-local.sh
```

### 🗺️ Roadmap & Milestones
[x] M0: Infrastructure Foundation — Monorepo setup, Terraform baseline, OIDC CI/CD pipeline, and local Docker/LocalStack emulation. (Current)

[ ] M1: ECS Services & Database Migration — VPC, RDS PostgreSQL, RDS Proxy, and deploying Fargate container tasks.

[ ] M2: API Gateway & Auth Integration — AWS API Gateway routing, Cognito/Auth microservice handshake.

[ ] M3: S3 Fan-Out & Async Worker Pipeline — Lambda workers, SQS queue integration, and file distribution.

[ ] M4: React SPA & CloudFront Deployment — Frontend integration, S3 static hosting, and global CDN delivery.

[ ] M5: Production Hardening & Monitoring — Observability, alarms, scaling policies, and final security audit.

### 📄 Documentation
Detailed guides and operational documentation are located in the docs/ directory:
- `DOCBRIDGE_BLUEPRINT.md`
- `DOCBRIDGE_TDD.md`
- `DESIGN_REQUIREMENTS.md`
- `adrs/ADR-001-public-ingress-edge.md`
- `adrs/ADR-002-service-decomposition.md`
- `adrs/ADR-003-data-persistence-and-storage.md`
- `adrs/ADR-004-authentication-and-authorization.md`
- `adrs/ADR-005-event-driven-messaging.md`
- `adrs/ADR-006-caching-strategy.md`
- `adrs/ADR-007-api-design-and-versioning.md`
- `adrs/ADR-008-observability-and-monitoring.md`
- `adrs/ADR-009-ci-cd-pipeline-architecture.md`
- `adrs/ADR-010-disaster-recovery-and-backups.md`
- `adrs/ADR-011-security-and-compliance.md`
- `adrs/ADR-012-performance-and-scalability.md`
- `adrs/ADR-013-infrastructure-as-code.md`


### 📜 License
Distributed under the MIT License. See LICENSE for more information.

