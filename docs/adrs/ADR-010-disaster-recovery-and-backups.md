# ADR-010: Error Handling & Retry Strategies 

## ADR-010: Error Handling & Retry Strategies 

### Context 

When processing up to 2,000 file tasks across 20 different destinations, network drops, rate limits (HTTP 429), and temporary target outages will happen. Without a clear retry strategy, retrying failed tasks immediately creates a "retry storm" that hammers recovering downstream servers in synchronized waves. On the other hand giving up too early causes valid uploads to fail on temporary cut offs. We need a system that automatically recovers from transient network glitches while immediately isolating permanent failures. 

### Decision Required 

How do we structure our retry, backoff, and failure handling strategies so that transient network cut offs recover automatically without overloading downstream systems or failing entire batch jobs? 

### Options Evaluated 

###### **Option 1: Immediate Fixed-Delay Retries (In-Worker Loop)** 

- **Pro 1 (Simple Code):** Easy to implement inside worker code using a standard loop (try 3 times with a 2-second pause between attempts). 

- **Pro 2 (Fast Recovery):** Restores temporary connections quickly if a cut off lasts only a fraction of a second. 

- **Con 1 (Retry Storms):** If 500 workers fail simultaneously during a network hiccup, they will all retry at the exact same millisecond, crushing the recovering destination server. 

- **Con 2 (Resource Waste):** Keeps worker instances occupied and hanging open while waiting out fixed delays. 

###### **Option 2: SQS Native Visibility Timeout with Exponential Backoff, Jitter & DLQ** 

- **Pro 1 (Prevents Lockstep Stampedes):** Uses SQS visibility timeouts with exponential backoff (2s, 4s, 8s...) and random time offsets (jitter) so retries spread out evenly rather than hitting servers in waves. 

- **Pro 2 (Dead Letter Queue Failure Isolation):** If a file task fails 3 times ( **maxReceiveCount = 3** ), SQS automatically moves it to **docbridge-task-dlq** . The single bad file can be inspected later without stopping or failing the remaining 1,999 uploads. 

- **Con 1 (Slight Delay on Cut Offs):** Takes slightly longer for a task to finish recovering because the backoff timer grows longer with each failed attempt. 

- **Con 2 (Requires Idempotency):** Workers must verify the task status in PostgreSQL 

before processing to make sure duplicate SQS message deliveries never write duplicate data. 

###### **Option 3: Circuit Breaker Pattern via Redis Global State** 

- **Pro 1 (Protects Outaged Targets):** Centralizes destination health checks in Redis. If Destination A fails 10 calls in a row, the circuit "trips" open and instantly pauses all tasks headed to Destination A for 5 minutes without attempting new network connections. 

- **Pro 2 (Zero Wasted Bandwidth):** Immediately skips network calls to known-broken destinations, saving system memory and bandwidth. 

- **Con 1 (High Operational Overhead):** Requires setting up a Redis cluster and writing complex state management across all worker nodes. 

- **Con 2 (Overkill for V1 Launch):** Adds extra architecture complexity when simple SQS backoff handles 95% of transient cut offs effectively. 

### Decision 

###### **Option 2: SQS Native Visibility Timeout with Exponential Backoff, Jitter & DLQ** 

### Rationale & Defense 

- **Direct Match to Requirements:** Option 2 handles retries natively at the queue layer. Exponential backoff and jitter stop retry storms against downstream destinations, while the Dead Letter Queue isolates permanent errors so 1 corrupt file or permission issue never aborts an entire 2,000-file batch. 

- **Mitigated Risk:** We protect against SQS's at-least-once delivery behavior by enforcing worker-level idempotency. Every worker checks PostgreSQL using **task_id** before running execution logic, guaranteeing that retried tasks never create duplicate database rows or file versions. 

- **Upgrade/Migration Path:** If specific high-volume destination endpoints experience frequent prolonged outages down the road, we can layer Option 3 (a Redis-based Circuit Breaker) on top of our worker fleet without needing to restructure our SQS queues or database schemas. 

**Ratified by:** Emre Tekinalp 

**Date:** Aug 21, 2026 