# ADR-007: Queue & Worker TopologyManagement 

## ADR-007: Queue & Worker Topology 

### Context 

When users submit multiple files across various destinations and teams simultaneously, it creates a massive volume of job requests that must be processed asynchronously. Without a properly configured queue architecture, this volume creates critical system risks: 

- **Bottlenecks & Traffic Jams:** A single job can contain hundreds or thousands of files. If handled improperly, one crashing file will stall or fail the entire batch of 1,999 remaining uploads. 

- **Destination Outages:** An outage or access issue at a specific target location shouldn't impact or abort data transfers heading to healthy destinations. 

- **Server Overload:** Processing thousands of tasks simultaneously without load controls will overload database connections and downstream servers, affecting other areas of the system. 

Even when using AWS SQS, we must explicitly structure our queue topology and workers to isolate individual task failures and prevent server overload. 

### Decision Required 

How do we design an asynchronous queue and worker topology that processes batch submissions in parallel across multiple users and destinations without causing bottlenecks, server overload, or total job failures during destination outages? 

### Options Evaluated 

###### **Option 1: Single Queue with Monolithic Batch Processing** 

- **Pro 1 (Development Speed):** Extremely simple to set up and build quickly because you only manage one SQS queue and one worker script. 

- **Pro 2 (Observability):** Easier to track and log in the beginning since a whole job request lives inside a single queue message. 

- **Con 1 (Head-of-Line Blocking):** If one file out of 2,000 crashes or takes 10 minutes to process, it stalls or fails the entire batch for the user. 

- **Con 2 (Resource Starvation):** Large batch spikes can easily trigger SQS visibility timeouts or exhaust database connection pools during processing. 

###### **Option 2: Two-Stage Decoupled Queue with Fan-Out & S3 Event Execution** 

- **Pro 1 (Failure Isolation):** Individual file deliveries are completely isolated. If 1 file fails 3 times, it lands in a Dead Letter Queue ( **docbridge-task-dlq** ) while the other 1,999 files complete without issue. 

- **Pro 2 (Controlled Concurrency):** Capping active task workers protects PostgreSQL database connection pools and downstream APIs from getting overwhelmed. 

- **Con 1 (Architectural Complexity):** Requires setting up and maintaining multiple SQS queues, fan-out logic, and S3 event triggers in Infrastructure as Code. 

- **Con 2 (Debugging Overhead):** Tracing a single job requires checking log streams across two distinct queues and worker types instead of just one. 

###### **Option 3: Managed Serverless State Machine (AWS Step Functions)** 

- **Pro 1 (Built-In Visual Observability):** Provides an out-of-the-box visual UI dashboard where you can see every single execution step and inspect failing tasks in real time without custom logging. 

- **Pro 2 (Zero Custom Fan-Out Code):** AWS manages all task loops, retries, and error routing automatically through state machine definitions, reducing custom worker code. 

- **Con 1 (High Cost at Scale):** Step Functions charges per state transition, processing 2,000 tasks per batch across multiple concurrent users generates massive AWS bills compared to SQS. 

- **Con 2 (Execution & Payload Quotas):** High-volume batch submissions risk hitting strict AWS Step Functions history limits, payload size caps, and API rate limits. 

### Decision 

###### **Option 2: Two-Stage Decoupled Queue with Fan-Out & S3 Event Execution** 

### Rationale & Defense 

- **Direct Match to Requirements:** Option 2 directly fixes our main traffic jam and server crash risks. By breaking 1 big job into 2,000 separate task messages in SQS, a single crashed or stuck file will never stop the remaining 1,999 files from delivering. Setting a cap of 50 active workers also stops our database from getting overloaded when many users submit batches at the exact same time. 

- **Mitigated Risk:** The main downside of Option 2 is that it takes more work to set up and SQS can sometimes deliver the same task message twice. We solve this in our code by having workers check the task ID in the database before doing any work. If a task is already marked as done, the worker simply skips it so we never save duplicate files or break our database records. 

- **Upgrade/Migration Path:** If our app traffic explodes down the road, we can swap out our SQS queues for AWS Step Functions without touching our core app code. Because our API, database, and background workers are kept separate from each other, changing how messages are passed behind the scenes won't break our main file upload logic. 

**Ratified by:** Emre Tekinalp 

**Date:** Aug 21, 2026 