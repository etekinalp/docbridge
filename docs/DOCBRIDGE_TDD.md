# **Technical Design for PAS-101: DocBridge** 

**Status:** Draft **Blueprint:** DOCBRIDGE_BLUEPRINT_TEKINALP **ADRs:** DOCBRIDGE_ADR_TEKINALP **Collaborators:** Emre Tekinalp 

### **Rules for implementation:** 

- **IaC:** All resources created via Terraform ( **infra/modules/*** called by **infra/envs/*** ). Console for reading only. 

- **CI/CD:** Independent GitHub Actions pipeline per service with path triggers. 

- **Local First:** LocalStack for S3/SQS, Docker Compose for local PostgreSQL and APIs. 

- **Secrets:** AWS Secrets Manager + env variables (zero hardcoded secrets). 

- **Decisions:** When a part hits a decision with real competing options, stop and write an ADR using the template before implementing. Decisions with one obvious answer get a one-line note in this doc, not an ADR. 

### **Build philosophy** 

- Milestones follow the Blueprint's 4 core user flows. Each milestone from M1 to M4 ends with a functional feature you can test in the browser. 

- Within a milestone: when a flow touches a service, build that service close to its full project scope rather than a thin slice. Reopening a service later to add one endpoint creates context-switching overhead and re-testing cost. 

### **Estimate compression logic (AI-assisted implementation)** 

**Estimates assume AI-assisted implementation** (Cursor, Claude Code, etc.): AI generates boilerplate, Terraform modules, and unit tests, while the lead engineer reviews and verifies. 

- **Boilerplate** (CRUD routes, Terraform modules, compose files, CI YAML, UI scaffolding): compressed 50–60%. 

- **Concurrency-sensitive logic** (submission transactions, worker claims/retries, idempotency): compressed 30–40%. The bottleneck is reasoning about edge cases and interleavings, not code typing. 

- **Infra wiring and cloud debugging** (VPC endpoints, IAM policies, API Gateway routes): compressed minimally. Bounded by AWS deployment propagation times, not typing speed. 

### **Milestones** 

|**Milestone**|**Flow**|**Estimate**|**Demoable at the**<br>**end**|
|---|---|---|---|
|M0|Foundations (no flow)|4.5 d|Infrastructure live,<br>CI/CD green,<br>LocalStack/Docker<br>running locally|
|M1|Flow 1: Browse<br>destinations|9.0 d|Authenticate via<br>Cognito, browse<br>folder tree in browser|
|M2|Flow 2: Distribute a<br>batch|9.5 d|Direct S3 uploads,<br>map destinations,<br>submit 2,000 tasks,<br>verify delivery|
|M3|Flow 3: Track a job|6 d|Watch real-time task<br>progress flip live via<br>WebSockets|
|M4|Flow 4: Retrieve a file|1 d|Download button<br>returns file via<br>team-scoped<br>presigned GET|
|M5|Hardening + E2E<br>verification|2 d|System load metrics<br>and security checks<br>proven on dev<br>environment|
|**Total**||**32 d**||



### **Repository and environment structure** 

`docbridge/` ├── `services/` 

│ ├── `platform/          # Platform service & migrations` │ └── `docbridge-api/     # DocBridge core API & migrations` ├── `workers/` 

│ ├── `fanout/            # SQS Job fan-out worker (ADR-007)` 

│ ├── `delivery/          # SQS Task delivery worker (ADR-010)` │ └── `ws/                # WebSocket API Gateway handlers (ADR-008)` ├── `web/                   # React + Vite SPA (ADR-006)` ├── `packages/` 

│ └── `shared/            # Cognito JWKS validator (ADR-004/009), OTel |                           Tracer (ADR-011), shared types` ├── `infra/` │ ├── `modules/           # Terraform: vpc, rds, ecs, sqs, s3, cognito, | |                       api-gateway` │ ├── `envs/` │ │ ├── `dev/` │ │ └── `prod/` │ └── `bootstrap/         # Terraform state S3 bucket + DynamoDB lock |                           (ADR-012)` ├── `docker-compose.yml` └── `.github/workflows/` 

##### **Database Architecture Overview** 

The system utilizes **3 isolated logical databases** running on a single PostgreSQL instance with per-service database credentials (ADR-009). Foreign keys are enforced strictly _within_ each service boundary cross-service references are plain UUIDs validated through internal API calls. 

##### **1. Auth Database (auth_db)** 

While user authentication (login, password hashing, and token issuance) is offloaded to AWS Cognito (ADR-004), the Auth database maintains machine-to-machine credentials for background workers (ADR-009). 

``` SQL
-- Service Clients for Background Workers (Machine-to-Machine Auth)
CREATETABLE service_clients (
idUUID PRIMARY KEYDEFAULT gen_random_uuid(),
  client_id TEXTUNIQUENOTNULL,       -- e.g. 'delivery-worker'
  client_secret_hash TEXTNOTNULL,
  scopes TEXT[] NOTNULL,               -- e.g. ['documents:ingest']
  created_at TIMESTAMPTZ NOTNULLDEFAULTnow()
);
```

**Note on User Authorization:** User identities are represented across Platform and DocBridge services as plain user_id UUIDs matching the Cognito sub claim. Access rights are derived in real-time from team_members membership in the platform database. 

##### **2. Platform / File Management Database (platform_db)** 

Manages organization structures, target binders, folder hierarchies, and long-term document storage. 

``` SQL
CREATETABLE teams (
idUUID PRIMARY KEYDEFAULT gen_random_uuid(),
nameTEXTNOTNULL,
  region TEXTNOTNULL,
  docbridge_enabled BOOLEANNOTNULLDEFAULTtrue,
  created_at TIMESTAMPTZ NOTNULLDEFAULTnow()
);
CREATETABLE team_members (
  team_id UUIDREFERENCES teams(id),
  user_id UUIDNOTNULL,               -- Cognito sub UUID (no cross-db FK)
  added_at TIMESTAMPTZ NOTNULLDEFAULTnow(),
  PRIMARY KEY (team_id, user_id)
);
CREATEINDEX idx_team_members_user ON team_members(user_id);

CREATETABLE binders (
idUUID PRIMARY KEYDEFAULT gen_random_uuid(),
  team_id UUIDNOTNULLREFERENCES teams(id),
nameTEXTNOTNULL,
  created_at TIMESTAMPTZ NOTNULLDEFAULTnow()
);
CREATEINDEX idx_binders_team ON binders(team_id);
CREATETABLE folders (
idUUID PRIMARY KEYDEFAULT gen_random_uuid(),
  binder_id UUIDNOTNULLREFERENCES binders(id),
  parent_folder_id UUIDREFERENCES folders(id), -- NULL = binder root
nameTEXTNOTNULL,
  created_at TIMESTAMPTZ NOTNULLDEFAULTnow()
);
CREATEINDEX idx_folders_parent ON folders(binder_id, parent_folder_id);
CREATETABLE documents (
idUUID PRIMARY KEYDEFAULT gen_random_uuid(),
  binder_id UUIDNOTNULLREFERENCES binders(id),
  folder_id UUIDREFERENCES folders(id),
nameTEXTNOTNULL,
  size_bytes BIGINTNOTNULL,
  content_type TEXTNOTNULL,
  checksum_sha256 TEXTNOTNULL,
  source_task_id UUIDUNIQUE,           -- Enforces delivery idempotency
  uploaded_by_user_id UUIDNOTNULL,   -- The onBehalfOf user
  created_at TIMESTAMPTZ NOTNULLDEFAULTnow()
);
```

**Idempotency Guarantee:** source_task_id UNIQUE ensures that if a background worker retries a task delivery, the platform executes an ON CONFLICT (source_task_id) DO NOTHING and returns the existing document_id without creating duplicate files. 

##### **3. DocBridge Database (docbridge_db)** 

Tracks uploaded staging files, job submissions, distributed task execution, and WebSocket subscriber states. 

``` SQL
CREATETABLE jobs (
idUUID PRIMARY KEYDEFAULT gen_random_uuid(),
  submitted_by_user_id UUIDNOTNULL,
  task_count INTNOTNULL,
  completed_at TIMESTAMPTZ,             -- Set when all tasks resolve
  created_at TIMESTAMPTZ NOTNULLDEFAULTnow()
);

CREATEINDEX idx_jobs_user ON jobs(submitted_by_user_id, created_at DESC);
CREATETABLE files (
idUUID PRIMARY KEYDEFAULT gen_random_uuid(),
  owner_user_id UUIDNOTNULL,
  job_id UUIDREFERENCES jobs(id),       -- NULL until batch submission
  original_name TEXTNOTNULL,
  size_bytes BIGINTNOTNULL,
  content_type TEXTNOTNULL,
  checksum_sha256 TEXTNOTNULL,
  s3_key TEXTNOTNULL,                 --
staging/{owner_user_id}/{file_id}
  created_at TIMESTAMPTZ NOTNULLDEFAULTnow()
);

CREATETABLE tasks (
idUUID PRIMARY KEYDEFAULT gen_random_uuid(),
  job_id UUIDNOTNULLREFERENCES jobs(id),
  file_id UUIDNOTNULLREFERENCES files(id),
  team_id UUIDNOTNULL,
  binder_id UUIDNOTNULL,
  folder_id UUID,                       -- NULL = binder root
  region TEXTNOTNULL,
statusTEXTNOTNULLDEFAULT'pending'
CHECK (statusIN ('pending', 'in_progress', 'completed', 'failed')),
  platform_document_id UUID,
  attempt_count INTNOTNULLDEFAULT0,
  failure_reason TEXT,
  created_at TIMESTAMPTZ NOTNULLDEFAULTnow(),
  updated_at TIMESTAMPTZ NOTNULLDEFAULTnow()
);

-- Partial Unique Indexes to guard against duplicate destinations
CREATEUNIQUEINDEX uq_tasks_dest ON tasks(file_id, team_id, binder_id,
folder_id)

WHERE folder_id ISNOTNULL;
CREATEUNIQUEINDEX uq_tasks_dest_root ON tasks(file_id, team_id,
binder_id)
WHERE folder_id ISNULL;
CREATEINDEX idx_tasks_job_status ON tasks(job_id, status);
CREATETABLE ws_connections (
  connection_id TEXT PRIMARY KEY,       -- AWS API Gateway WebSocket
connection ID
  user_id UUIDNOTNULL,
  job_id UUID,                          -- Active job subscription
  connected_at TIMESTAMPTZ NOTNULLDEFAULTnow()
);
CREATEINDEX idx_ws_job ON ws_connections(job_id);
```

##### **Technical Design Patterns & SQL Strategies** 

- **Duplicate-Destination Guard:** Standard UNIQUE constraints silently fail when comparing NULL values (NULL != NULL in SQL). Using a pair of partial unique indexes (WHERE folder_id IS NOT NULL and WHERE folder_id IS NULL) enforces uniqueness for both folder subtrees and binder root destinations. 

- **Single Aggregate Query for Paginated Jobs (GET /jobs):** To avoid N+1 queries when fetching a user's job list, task status counts are computed in a single pass using conditional SQL aggregations: 

``` SQL
SELECT
  j.id,
  j.created_at,
  j.task_count,
count(*) FILTER (WHERE t.status = 'pending') AS pending,
count(*) FILTER (WHERE t.status = 'in_progress') AS in_progress,
count(*) FILTER (WHERE t.status = 'completed') AS completed,
count(*) FILTER (WHERE t.status = 'failed') ASfailed
FROM jobs j
LEFTJOIN tasks t ON t.job_id = j.id
WHERE j.id = ANY($pageOfJobIds)
GROUPBY j.id;
```

- **WebSocket Pub/Sub State (ws_connections):** Because API Gateway WebSocket API only manages raw sockets without built-in pub/sub mechanisms, this table tracks active job subscriptions so workers push progress messages strictly to relevant users. 

### **API Design & Contracts** 

All endpoints exchange JSON payloads, enforce HTTPS, require a valid JWT in the Authorization: Bearer <token> header (unless marked public), and return a standardized error format: 

``` JSON
{
  "error": {
    "code": "INVALID_CHECKSUM",
    "message": "The calculated SHA-256 does not match the provided file
header."
  }
}
```

###### **Auth & Token Specifications** 

Authentication and machine-to-machine service access are backed by AWS Cognito (ADR-004, ADR-009). 

- **User Access Tokens:** Short-lived (15-minute) RS256 JWTs containing sub (user UUID), email, iat, and exp claims. 

- **Worker Service Tokens:** Short-lived Machine-to-Machine JWTs fetched via OAuth client credentials containing sub (client ID), scope (['documents:ingest']), and token_use: 'service' claims. 

- **Public Key Verification:** Internal microservices fetch public keys from AWS Cognito's /.well-known/jwks.json endpoint to verify signatures locally without hitting the database. 

###### **Platform API Contracts** 

Handles organizational structure, team memberships, target binders, and file ingestion. 

###### **User-Token Routes (Forwarded JWT)** 

|**Method & Path**|**Request /**<br>**Parameters**|**Response**<br>**Payload**|**Description**|
|---|---|---|---|
|**GET**<br>/teams?docbridgeEnabled=tru<br>e|None|200 [{id, name,<br>region}]|List teams the user<br>belongs to.|
|**GET** /teams/:teamId/binders|None|200 [{id,<br>name}]|List team binders<br>(returns403if<br>non-member).|
|**GET**<br>/binders/:binderId/contents|?folderId=<uui<br>d>|200 {folders:<br>[...],<br>documents:<br>[...]}|Expand one folder<br>level in a binder.|



###### **Service-Token Routes (Scope: documents:ingest)** 

|**Method & Path**|**Request /**<br>**Parameters**|**Response**<br>**Payload**|**Description**|
|---|---|---|---|
|**GET**<br>/teams/:teamId/members/:userId|None|200 {addedAt}<br>or404|Validates team<br>membership<br>(status code<br>carries the<br>result).|
|**POST** /documents|Multipart<br>stream:<br>metadata +<br>file bytes|201<br>{documentId}|Background<br>worker delivers<br>file. Enforces<br>source_task_id<br>idempotency.|



_Ingestion Integrity:_ The platform recalculates the SHA-256 hash on received file streams and rejects mismatches with 422 CHECKSUM_MISMATCH. 

###### **DocBridge Core API Contracts** 

Handles presigned S3 upload issuance, batch job expansion, status tracking, and download URLs. 

|**Method & Path**|**Request Body / Params**|**Response**<br>**Payload**|**Behavior & Limits**|
|---|---|---|---|
|**GET**<br>/destinations/team<br>s|None|200 [{id, name,<br>region}]|Proxies Platform<br>API, filtered to<br>docbridgeEnabled=t<br>rue.|



|**POST** /files|{files: [{name, sizeBytes,<br>contentType, sha256}]}|201 [{fileId,<br>upload: {url,<br>fields}}]|Max 100 files per<br>call. Generates S3<br>presigned POST<br>URLs or multipart<br>plans.|
|---|---|---|---|
|**POST** /jobs|{mappings: [{fileId,<br>destinations: [{teamId,<br>binderId, folderId?}]}]}|201 {jobId,<br>taskCount}|Expands mappings<br>into up to 2,000<br>tasks in a single<br>transaction<br>(<500ms p99).|
|**GET** /jobs|?page=1&limit=20|200 [{jobId,<br>createdAt,<br>taskCount,<br>counts,<br>aggregateStat<br>us}]|Single aggregate<br>SQL query across<br>all paginated job<br>rows.|
|**GET**<br>/jobs/:id/tasks|?status=failed&page=1&lim<br>it=100|200 [{id, fileId,<br>status,<br>failureReason}<br>]|Paginated task<br>detail list.|
|**POST**<br>/files/:fileId/downl<br>oad-url|None|200 {url,<br>expiresIn: 120}|Generates 2-minute<br>presigned GET URL<br>after verifying team<br>access.|



_Upload Conditions:_ Presigned URLs enforce exact Content-Type matching (allow-list: pdf, docx, xlsx, png, jpg), hard-capped file size limits (1 GB ceiling), and S3 checksum checks (x-amz-checksum-sha256). URLs expire after 15 minutes. 

#### **WebSocket API Contracts (AWS API Gateway WebSocket)** 

###### **Connection Handshake ($connect)** 

- **URL:** wss://[ws.docbridge.com/dev?token=](https://ws.docbridge.com/dev?token=)<cognito_us er_jwt> 

- **Behavior:** Validates JWT against JWKS. On success, inserts connection details into ws_connections table. Unauthenticated connections return 401. 

###### **Subscribe Action** 

``` JSON
{
  "action": "subscribe",
  "jobId": "8f3b2a12-984c-4e89-a212-32b0018a421a"
}
```

_Behavior:_ Validates that the subscriber shares team access with the job owner, then updates job_id on the client's ws_connections row. 

###### **Server Push Message (task_update)** 

``` JSON
{
  "type": "task_update",
  "jobId": "8f3b2a12-984c-4e89-a212-32b0018a421a",
  "taskId": "c92d021b-5e1a-4554-b312-9981a1710042",
  "status": "completed",
  "failureReason": null,
  "counts": {
    "pending": 0,
    "in_progress": 2,
    "completed": 1997,
    "failed": 1
  }
}
```

_Behavior:_ Aggregate task counts ride along in the payload so the frontend updates UI state immediately without making extra API calls. 

## **Milestone Execution Plan** 

##### **M0: Infrastructure Foundations & CI/CD Setup** 

**Estimate:** 4.5 Days 

**User Flow:** N/A (Foundations) 

**Deliverable:** Infrastructure live in AWS dev account, LocalStack Docker Compose environment operational, automated CI/CD pipelines active. 

###### ● **Infrastructure & Bootstrap:** 

- Configure S3 bucket and DynamoDB table for Terraform remote state (infra/bootstrap). 

- Implement base Terraform modules (infra/modules/): VPC, subnets, Security Groups, RDS PostgreSQL, LocalStack configuration. 

- Provision AWS Cognito User Pool and App Clients (User OAuth & M2M Client Credentials). 

###### ● **Developer Workflows & CI/CD:** 

- Build local docker-compose.yml bringing up PostgreSQL, LocalStack (S3, SQS), and hot-reloading service containers. 

- Configure path-filtered GitHub Actions workflows (.github/workflows/) for automated testing and linting across all services. 

- Package shared libraries (packages/shared): Cognito JWKS token verifier middleware, standard error shapes, OpenTelemetry tracer setup. 

##### **M1: Flow 1 Browse Destinations** 

**Estimate:** 9.0 Days 

**User Flow:** Flow 1 (Browse Target Destinations) 

**Deliverable:** Authenticate via Cognito, open the web app, and browse the hierarchical tree of teams, binders, and folders in real time. 

###### ● **Platform Database & API Service:** 

- Execute platform_db migrations (teams, team_members, binders, folders, documents). 

- Implement Row-Level Security (RLS) policies on binders and documents tables. 

- Build full route set: 

   - GET /teams: Lists user teams. 

   - GET /teams/:teamId/binders: Lists team binders. 

   - GET /binders/:binderId/contents: Single-level folder tree lookup. 

   - GET /teams/:teamId/members/:userId: Validates membership for internal services. 

   - POST /documents: File ingestion route (built early per Build Philosophy to avoid reopening in M2). 

###### ● **DocBridge API Service:** 

- Implement GET /destinations/teams route proxying Platform API results. 

###### ● **Web SPA:** 

- Integrate Cognito Hosted UI / PKCE token exchange flow. 

- Build tree browser UI component with lazy-loading binder/folder branches. 

##### **M2: Flow 2 Distribute a Batch** 

**Estimate:** 9.5 Days 

**User Flow:** Flow 2 (Batch File Upload and Distribution Submission) 

**Deliverable:** Upload files via presigned S3 URLs, select target destinations, submit batch job, and confirm documents arrive in Platform DB. 

###### ● **DocBridge Database & Core API:** 

- Execute docbridge_db migrations (files, jobs, tasks, ws_connections). 

- Implement POST /files: Generates S3 presigned POST URLs with strict header constraints (Content-Type, max 1 GB size, SHA-256). 

- Implement POST /jobs: Expands file-to-destination mappings into up to 2,000 tasks inside a single database transaction (<500ms p99) and enqueues job event to SQS Fanout queue. 

###### ● **Background Workers:** 

- **Fanout Worker:** Pulls job events from SQS, splits task batches, and enqueues to Delivery SQS queue. 

- **Delivery Worker:** Pulls task events, fetches worker M2M token, streams file from S3 staging to Platform POST /documents. 

- **Idempotency Guard:** Worker handles duplicate deliveries via Platform source_task_id unique constraint (ON CONFLICT DO NOTHING). 

###### ● **Web SPA:** 

- Implement direct-to-S3 file dropzone uploader. 

- Build destination mapping matrix UI and batch submission handler. 

##### **M3: Flow 3 Track a Job** 

###### **Estimate:** 6.0 Days 

**User Flow:** Flow 3 (Real-time Batch Execution Monitoring) 

**Deliverable:** Open job progress dashboard and watch task statuses (pending, in-progress, completed, failed) update live over WebSockets without manual refreshes. 

###### ● **WebSocket Infrastructure & API Gateway:** 

   - Terraform module for AWS API Gateway WebSocket API and Lambda integration routes ($connect, $disconnect, subscribe). 

   - Manage active connections and subscriptions in ws_connections table. 

- **DocBridge API & Worker Pub/Sub:** 

- Delivery workers push status update payloads directly to API Gateway WebSocket management endpoint upon task resolution. 

- Implement GET /jobs: Paginated user job summary using single conditional aggregation query. 

- Implement GET /jobs/:id/tasks: Filtered task list view (?status=failed). 

###### ● **Web SPA:** 

- Build execution tracking dashboard with real-time progress bars and aggregate task counters. 

- Implement WebSocket client auto-reconnect logic with token refreshing. 

##### **M4: Flow 4 Retrieve a File** 

###### **Estimate:** 1.0 Day 

**User Flow:** Flow 4 (Download Delivered File) 

**Deliverable:** Click download button on a completed task to fetch file directly from S3 staging via team-authorized presigned URL. 

###### ● **DocBridge Core API:** 

- Implement POST /files/:fileId/download-url: Verifies requesting user has active team membership via Platform API and generates 2-minute presigned S3 GET URL. 

###### ● **Web SPA:** 

- Wire download action button inside task detail drawer to initiate secure browser download stream. 

##### **M5: Hardening & E2E Verification** 

**Estimate:** 2.0 Days 

**User Flow:** End-to-End System Audit 

**Deliverable:** Full end-to-end load verification, trace audit, and security validation in deployed dev environment. 

- **End-to-End Integration Testing:** Execute simulated 2,000-task distribution workloads and verify completion time SLAs. 

- **Distributed Tracing Audit:** Verify trace ID continuity across HTTP REST API, SQS message metadata, background workers, and Platform ingestion calls in OpenTelemetry/Jaeger. 

- **Security & Failure Injection:** Run RLS boundary test suites across separate tenants and simulate worker crashes to verify message retry queues (DLQ) and idempotency. 

### **Concurrency Architecture** 

###### **1. Mass Job Submission (2,000 Tasks in <500ms)** 

- **The Race Condition:** Inserting a job and 2,000 individual task records via standard loop inserts causes heavy database connection pooling bottlenecks and request timeouts. 

- **Our Solution:** A single atomic SQL batch insertion executed inside one database transaction. The API parses the payload, validates destination permissions, and runs a single bulk INSERT INTO tasks (job_id, file_id, team_id, binder_id, folder_id, status) VALUES (...) statement. If any destination validation fails or database connection drops mid-transaction, the entire batch rolls back safely without orphaned tasks. 

###### **2. Distributed Worker Claims & Idempotent Delivery** 

- **The Race Condition:** SQS guarantees _at-least-once_ delivery. If a network blip occurs, SQS may deliver the exact same task message to two separate delivery workers at the same time, risking double uploads to the Platform database. 

- **Our Solution:** Two-tier concurrency safety: 

   - **Database Uniqueness Guard:** The tasks table enforces partial unique indexes ( uq_tasks_dest and uq_tasks_dest_root ). A file cannot be mapped to the exact same binder/folder twice within the same job. 

   - **Ingest Idempotency:** When workers deliver files to Platform API ( POST /documents ), they pass source_task_id . Platform DB inserts the record with ON CONFLICT (source_task_id) DO NOTHING . If Worker B attempts to deliver a task that Worker A just completed, Platform DB swallows the duplicate gracefully and returns the existing document_id . 

###### **3. Atomic Task Updates & Job Completion Check** 

- **The Race Condition:** As 2,000 parallel workers finish tasks, two workers finishing the final two remaining tasks at the exact same millisecond might both attempt to mark the parent job as completed_at = now() , or trigger duplicate completion webhooks. 

- **Our Solution:** Atomic state transitions at the task level: 

``` SQL
UPDATE tasks
SETstatus = 'completed', updated_at = now()
WHEREid = $1ANDstatusIN ('pending', 'in_progress')
RETURNING job_id;
```

After a task flips to completed , the worker executes a single check to test if any pending or in_progress tasks remain for that job_id . The final row update sets jobs.completed_at atomically. 

###### **4. WebSocket Fan-out Throttling (Preventing Connection Storms)** 

- **The Race Condition:** 2,000 workers completing tasks in a few seconds push 2,000 discrete WebSocket messages to AWS API Gateway, potentially exceeding connection rate limits or freezing the React frontend UI with constant re-renders. 

- **Our Solution:** Progress counts are aggregated and sent with task status payloads so the React SPA updates state in a single state batch rather than recalculating counts on every incoming socket frame. 

### **Failure Modes & Recovery Matrix** 

- **1. Staging Upload Failure (Direct S3 Presigned Upload)** 

   - **Failure Scenario:** Network drops mid-upload, presigned URL expires (15 min), or payload exceeds size limit (1 GB). 

   - **System Recovery:** Frontend detects non-200 response from S3 and requests a new presigned URL for remaining parts via multipart retry. S3 Lifecycle Policies automatically abort incomplete multipart uploads after 7 days and clean up unsubmitted staging files after 24 hours. 

- **2. Delivery Worker Crash Mid-Stream** 

   - **Failure Scenario:** A delivery worker node dies or suffers an AWS ECS eviction while actively streaming a file to POST /documents. 

   - **System Recovery:** SQS Visibility Timeout (5 minutes) expires without an explicit DeleteMessage acknowledgment. SQS redelivers the message to a healthy worker. The new worker retries the ingestion call using the existing source_task_id. Platform DB enforces ON CONFLICT (source_task_id) DO NOTHING, ensuring zero duplicate documents. 

- **3. Invalid Target Destination (Deleted Folder / Permissions Revoked)** 

   - **Failure Scenario:** A team binder or target folder is deleted after job submission but before the background worker processes the task. 

   - **System Recovery:** Platform API rejects the worker's ingest call with 404 NOT_FOUND. The worker immediately marks the task row in docbridge_db as status = 'failed' with failure_reason = 'TARGET_FOLDER_DELETED' and pushes a WebSocket task_update event to the user dashboard. The worker does not retry unrecoverable 4xx client errors. 

- **4. Downstream Platform Outage or Database Lock Contention** 

   - **Failure Scenario:** Platform API returns 503 Service Unavailable or 504 Gateway Timeout under extreme submission load. 

   - **System Recovery:** Delivery worker catches 5xx errors, increments attempt_count on the task record, and releases the message back to SQS with exponential backoff and randomized jitter. After 3 failed attempts, SQS routes the task to the Dead-Letter Queue (DLQ) and emits a CloudWatch alarm for engineering review. 

- **5. WebSocket Network Disconnection During Live Job Tracking** 

   - **Failure Scenario:** User closes laptop or loses Wi-Fi connection while viewing a active 2,000-task job dashboard. 

   - **System Recovery:** React SPA detects socket closure and triggers automatic exponential backoff reconnection (wss://...). Upon re-establishing connection ($connect), the SPA calls GET /jobs/:id via REST API to fetch a fresh aggregate snapshot of task counts, bringing the UI back into sync seamlessly. 

### **Security & Access** 

- **Authentication:** API Gateway JWT authorizer verifies AWS Cognito tokens at the network edge before traffic enters the VPC (ADR-001, ADR-004). Internal services re-verify signatures offline using Cognito’s public /.well-known/jwks.json keys. Background workers authenticate via short-lived Machine-to-Machine JWTs (ADR-009). 

- **Authorization & Multi-Tenancy:** 4-checkpoint verification model with zero implicit trust: 

   - _Edge Gateway:_ Validates signature and token expiration. 

   - _Platform API:_ Checks team_members membership on all folder/binder reads. 

   - _Worker Ingest:_ Verifies onBehalfOf user membership in real time at delivery. 

   - _PostgreSQL RLS:_ Enforces tenant_id database isolation policies (ADR-005). 

- **Secrets Management:** Database credentials, Cognito client secrets, and signing keys are stored in AWS Secrets Manager and injected as environment variables at runtime. CI pipelines run automated gitleaks scans to prevent accidental secret commits. 

- **Data Protection & Storage:** 

   - S3 staging objects encrypted at rest with AWS SSE-KMS (ADR-003) and enforced TLS in transit. 

   - Upload presigned POST URLs enforce strict content-type allow-lists (pdf, docx, xlsx, png, jpg), size ceilings (1 GB), and short expiry (15 min) (ADR-002). 

   - Download presigned GET URLs expire in 2 minutes and map strictly to individual object keys. 

- **Sensitive Data & Logging:** No PHI or sensitive document content in application logs. OpenTelemetry traces and logs record only task UUIDs, status codes, and sanitized failure reasons (ADR-011). 

### **Testing Strategy** 

- **Unit Testing:** Runs on every CI commit. Validates Cognito token verification, presigned S3 policy formatting, SQL task claim queries, aggregate status math, and transient vs. permanent error classifications. 

- **Integration Testing:** Runs nightly via Docker Compose and LocalStack. Simulates full batch flow locally: client upload -> job submission -> SQS fan-out -> delivery worker streaming -> Platform ingest ON CONFLICT DO NOTHING idempotency. 

- **End-to-End (E2E) & Load Testing:** Executed in the AWS dev environment during M5 before any production deployment: 

   - Verification of <500ms p99 submission latency for 2,000-task jobs. 

   - Partial-failure isolation testing (1 invalid destination fails while 1,999 complete). 

   - System recovery testing (killing Platform service mid-run to verify SQS retries and DLQ behavior). 

   - Security boundary auditing (cross-tenant access attempts return 404/403). 

### **Launch Plan** 

- **Database Migration Strategy:** Greenfield rollout. Each microservice executes its own forward-only SQL migrations from its local /migrations folder during task deployment. Non-backward-compatible schema changes follow an expand-then-contract pattern across separate deployments. 

- **Deployment Sequence:** Strictly follows ADR-001: core ECS services and internal ALBs deployed and health-checked inside the VPC first before API Gateway routes are created to expose them. 

- **Rollout & Feature Control:** Releases transition from M0 to M5 sequentially in dev. Production deployment requires manual approval environment gates in GitHub Actions. 

- **Rollback Procedures:** Application rollbacks execute by updating the ECS task definition to the previous Docker image SHA. Infrastructure rollbacks revert via terraform apply on previous state files. 

- **Retention & Monitoring:** S3 lifecycle rules automatically delete staging objects 30 days after creation. CloudWatch alarms monitor SQS DLQ depth (DLQDepth > 0) and delivery worker error rates to alert on immediate failures. 

