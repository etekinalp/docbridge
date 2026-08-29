# ADR-005: Asynchronous Task Execution 

## ADR-005: Asynchronous Task Execution & Queue Architecture 

### Context 

In ADR-004, we established that file binary transfers occur directly between the client browser and AWS S3 via Presigned URLs. Once an upload completes, **DocBridgeAPI** receives an event or notification to execute background tasks (processing documents, updating metadata, notifying external systems). 

These background tasks are resource-intensive and non-deterministic in duration (taking anywhere from 2 seconds to 5 minutes). Executing these tasks synchronously within HTTP request threads would tie up API container resources, risk gateway timeouts, and drop jobs if a container restarts during processing. We need a reliable mechanism to queue, retry, and execute background tasks asynchronously. 

### Decision Required 

How should we queue and process asynchronous background jobs triggered by **DocBridgeAPI** to ensure guaranteed message delivery, decoupled execution, and automatic retry capabilities? 

### Options Evaluated 

###### **Option 1: In-Memory / Local Queue inside DocBridgeAPI (e.g., BullMQ / Celery / Thread Pool)** 

- **Pro:** Simple initial setup. No additional cloud infrastructure to provision or pay for jobs are queued in server memory or a local worker thread. 

- **Con:** High risk of data loss. If the **DocBridgeAPI** container crashes or auto-scales down while tasks are queued in memory, those tasks vanish forever. Tasks also compete for CPU/RAM with the main API process. 

###### **Option 2: AWS SQS (Simple Queue Service) + Dedicated Worker Service** 

- **Pro:** Completely decoupled and persistent. **DocBridgeAPI** pushes a tiny JSON payload to AWS SQS in 5ms and responds to the user immediately. SQS safely holds the message across multiple availability zones. A dedicated **DocBridge-Worker** container pool reads messages from SQS at its own pace, scales independently, and 

automatically retries failed jobs via Dead Letter Queues ( **DLQ** ). 

- **Con:** Introduces new infrastructure ( **SQS queues** ) and requires managing a separate worker deployment target ( **DocBridge-Worker** ). 

###### **Option 3: Event Streaming Platform (e.g., AWS Kinesis or Apache Kafka)** 

- **Pro:** Supports massive real-time event streaming, infinite log replayability, and complex multi-consumer event processing. 

- **Con:** Massive operational complexity, steep learning curve, and significantly higher baseline cost. Total overkill for task-queue workflows. 

### Decision 

###### **Option 2: AWS SQS (Simple Queue Service) + Dedicated Worker Service** 

#### Rationale & Defense 

- **Direct Match to Requirements:** AWS SQS provides the exact asynchronous persistence and decoupling we need at minimal cost. By separating the API ( **DocBridgeAPI** ) from background execution ( **DocBridge-Worker** ), API response times remain blazingly fast regardless of background queue depth. 

- **Stability & Fault Tolerance:** SQS eliminates the data-loss risk of in-memory queues. If a background worker container crashes mid-task, SQS simply makes the message visible again for another worker to pick up. 

- **Dead Letter Queue (DLQ) Integration:** If a message fails processing after multiple retries (e.g. due to a corrupted file), SQS automatically routes it to a Dead Letter Queue ( **DLQ** ). This isolates broken jobs, prevents infinite error loops, and allows developers to inspect failed payloads without blocking the queue. 

**Ratified by:** Emre Tekinalp 

**Date:** Aug 14, 2026 