#!/usr/bin/env bash
set -e

echo "🚀 Initializing DocBridge Monorepo Setup (M0 Milestone)..."

# 1. Create Directory Hierarchy
mkdir -p .github/workflows
mkdir -p docs/adrs
mkdir -p infra/bootstrap
mkdir -p infra/modules/{vpc,rds,sqs,s3,cognito,api-gateway}
mkdir -p infra/envs/{dev,prod}
mkdir -p infra/local
mkdir -p packages/shared/src
mkdir -p services/platform/src/migrations
mkdir -p services/docbridge-api/src/migrations
mkdir -p workers/fanout/src
mkdir -p workers/delivery/src
mkdir -p workers/ws/src
mkdir -p web/src

echo "📂 Directory structure created."

# 2. Root package.json (npm Workspaces)
cat << 'EOF' > package.json
{
  "name": "docbridge",
  "private": true,
  "workspaces": [
    "packages/*",
    "services/*",
    "workers/*",
    "web"
  ],
  "scripts": {
    "build": "npm run build --workspaces",
    "test": "npm run test --workspaces",
    "lint": "npm run lint --workspaces",
    "dev:infra": "docker-compose up -d",
    "dev:infra:down": "docker-compose down"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
EOF

# 3. Base TypeScript Config
cat << 'EOF' > tsconfig.base.json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "declaration": true,
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  }
}
EOF

# 4. Package/Service Boilerplates
cat << 'EOF' > packages/shared/package.json
{
  "name": "@docbridge/shared",
  "version": "0.1.0",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "test": "echo \"Error: no test specified\" && exit 0"
  }
}
EOF

cat << 'EOF' > packages/shared/src/index.ts
// Shared utilities: Cognito JWKS validator, OTel Tracer, Error Shapes
export const APP_NAME = "DocBridge";
EOF

# Boilerplate package.json generator for internal services
for service in services/platform services/docbridge-api workers/fanout workers/delivery workers/ws web; do
  name=$(basename $service)
  cat << EOF > ${service}/package.json
{
  "name": "@docbridge/${name}",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "build": "echo \"Building ${name}...\"",
    "test": "echo \"No tests for ${name} yet\" && exit 0"
  }
}
EOF
done

# 5. Local Infrastructure Configuration (docker-compose.yml)
cat << 'EOF' > docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    container_name: docbridge-postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgrespassword
      POSTGRES_DB: auth_db
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./infra/local/init-db.sh:/docker-entrypoint-initdb.d/init-db.sh

  localstack:
    image: localstack/localstack:latest
    container_name: docbridge-localstack
    ports:
      - "4566:4566"
    environment:
      - SERVICES=s3,sqs,cognito-idp
      - AWS_DEFAULT_REGION=us-east-1
    volumes:
      - ./infra/local/init-aws.sh:/etc/localstack/init/ready.d/init-aws.sh

volumes:
  pgdata:
EOF

# 6. Database Initialization Script (3 Isolated Logical Databases)
cat << 'EOF' > infra/local/init-db.sh
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE platform_db;
    CREATE DATABASE docbridge_db;
EOSQL
EOF
chmod +x infra/local/init-db.sh

# 7. LocalStack Initialization Script (S3 & SQS setup)
cat << 'EOF' > infra/local/init-aws.sh
#!/bin/bash
echo "Initializing LocalStack S3 and SQS resources..."
awslocal s3 mb s3://docbridge-staging-dev
awslocal sqs create-queue --queue-name docbridge-job-fanout-dev
awslocal sqs create-queue --queue-name docbridge-task-delivery-dev
awslocal sqs create-queue --queue-name docbridge-task-dlq-dev
EOF
chmod +x infra/local/init-aws.sh

# 8. AI & VSCode Context Rules (.cursorrules)
cat << 'EOF' > .cursorrules
# DocBridge System Context & Guidelines

## Architecture Ground Rules
- Always consult `docs/BLUEPRINT.md` for business logic and flow boundaries.
- Always check `docs/TDD.md` for database schemas, API contracts, and concurrency mechanisms.
- Adhere strictly to ratified decision records in `docs/adrs/`.

## Key Technical Decisions
- **Infra:** Terraform modules only (`infra/modules/*` called by `infra/envs/*`).
- **DB Isolation:** 3 isolated logical DBs on 1 PostgreSQL instance (`auth_db`, `platform_db`, `docbridge_db`).
- **File Ingestion:** Direct-to-S3 uploads via presigned URLs (<500ms p99 job submission).
- **Idempotency:** Deliveries enforce `source_task_id` with `ON CONFLICT (source_task_id) DO NOTHING`.
EOF

# 9. GitHub Actions CI Workflow Setup
cat << 'EOF' > .github/workflows/ci-shared.yml
name: CI Baseline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
      - run: npm ci
      - run: npm run test
EOF

# 10. Document Stubs in docs/
cat << 'EOF' > docs/README.md
# DocBridge Documentation Workspace

Move your completed markdown specification files into this directory:
- `BLUEPRINT.md`
- `TDD.md`
- `DESIGN_REQUIREMENTS.md`
- `adrs/ADR-001-public-ingress-edge.md`
- `adrs/ADR-002-service-decomposition.md`
- ... (up to ADR-013)
EOF

echo "✅ Setup complete! Run the following commands to get started:"
echo "   chmod +x setup_m0.sh"
echo "   npm ci"
echo "   npm run dev:infra"