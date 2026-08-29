# ADR-011: System Monitoring & Observability 

## ADR-011: System Monitoring & Observability 

### Context 

When processing up to 2,000 file tasks across multiple SQS queue stages and distributed background workers, identifying where a specific task failed, stalled, or slowed down is extremely difficult. Standard unstructured logs make tracing a single job's lifecycle across the frontend API, fan-out worker, task queue, and storage services nearly impossible. We need an observability strategy that provides distributed tracing, structured logging, and metric alarms without blowing up telemetry storage costs. 

### Decision Required 

How do we structure system logging, distributed tracing, and performance monitoring to track individual file delivery tasks end-to-end without introducing vendor lock-in or excessive telemetry costs? 

### Options Evaluated 

###### **Option 1: Standard AWS CloudWatch Logs & Basic Alarms** 

- **Pro 1 (Zero Setup Overhead):** Works out of the box with zero third-party tools or custom trace propagation across SQS, Lambda, and PostgreSQL. 

- **Pro 2 (Simple Alerting):** Easily triggers SNS alerts when SQS Dead Letter Queue (DLQ) depth rises or when background worker error rates spike. 

- **Con 1 (Fragmented Logs):** Logs are scattered across multiple log groups querying a single job's path through fan-out and worker queues require complex log searches. 

- **Con 2 (No Distributed Visual Tracing):** Lacks span visibility, making it hard to see whether a delay happened in SQS queue wait time, database updates, or S3 transfers. 

###### **Option 2: CloudWatch with OpenTelemetry (OTel) Tracing & Structured JSON Logs** 

- **Pro 1 (End-to-End Distributed Tracing):** Uses standard OpenTelemetry headers attached to SQS message attributes to trace a single **job_id** and **task_id** seamlessly from API submission through to target delivery. 

- **Pro 2 (Vendor-Agnostic & Structured):** Standardized OTLP telemetry formats keep our code vendor-agnostic while enabling structured JSON logs that can be filtered instantly by job status or destination. 

- **Con 1 (Context Propagation Code):** Requires writing lightweight middleware in worker code to read trace headers from SQS message payloads. 

- **Con 2 (Sampling Rate Management):** Requires configuring trace sampling rules (e.g., sample 100% of errors, 5% of successful tasks) to keep telemetry costs low during 

massive 2,000-file runs. 

###### **Option 3: Third-Party Managed SaaS (e.g., Datadog / New Relic)** 

- **Pro 1 (Rich Out-of-the-Box Dashboards):** Provides turn-key distributed trace graphs, APM flame graphs, and automated anomaly detection with minimal manual configuration. 

- **Pro 2 (Unified Developer UX):** Gives engineers a single dashboard for log analytics, infrastructure metrics, and application performance. 

- **Con 1 (High Scaling Costs):** Ingestion pricing scales aggressively based on custom metrics, log volume, and worker execution counts. 

- **Con 2 (Data Boundary Risks):** Streaming operational telemetry and metadata outside our AWS VPC creates additional compliance and security review requirements. 

### Decision 

###### **Option 2: CloudWatch with OpenTelemetry (OTel) Tracing & Structured JSON Logs** 

### Rationale & Defense 

- **Direct Match to Requirements:** Option 2 gives us precise end-to-end trace visibility for every individual task in a batch job without locking us into proprietary platforms. Injecting trace IDs into SQS message headers allows developers to trace an entire file's lifecycle in seconds. 

- **Mitigated Risk:** We control telemetry ingestion costs by setting a dynamic trace sampling rate (sampling 100% of failed calls and DLQ items, but only 5% of healthy batch tasks) and enforcing structured JSON logging rules. 

- **Upgrade/Migration Path:** Because telemetry is built on open OpenTelemetry (OTel) standards, we can redirect our telemetry collector to external platforms like Datadog, Grafana, or Honeycomb at any point without rewriting application or worker instrumentation code. 

**Ratified by:** Emre Tekinalp 

**Date:** Aug 21, 2026 