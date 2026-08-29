# **Blueprint: DocBridge** 

**PAS-101** | **Status:** Draft | **Owner:** Emre Tekinalp | **Last Updated:** 09.August 2026 

### **1. What Problem We're Solving & Why** 

###### **Problem Statement** 

Clinical trial coordinators manage highly sensitive regulatory documentation across multi-region hospital networks. Currently, distributing files across global destinations requires coordinators to manually re-upload the exact same document multiple times into different target structures **(Hospital -> Team -> Binder -> Folder).** 

###### **Current State** 

Coordinators manually select, route, and re-upload individual files one destination at a time. This process is slow, highly repetitive, and lacks any centralized status tracking or delivery verification. 

###### **Impact** 

- Operational Bottlenecks: Coordinators waste hours repeating identical uploads and waiting on browser upload bars across fragile network connections. 

- Compliance & Financial Risk: Repetitive manual routing leads to misplaced regulatory documents, triggering costly compliance failures during audits. 

- Lack of Visibility: No central audit history exists to track delivery progress or identify whether a file reached its target directory or failed silently. 

###### **Definition of Done** 

A coordinator selects a batch of clinical trial documents (up to 50 GB) and maps them to multiple target destinations in a single UI session. The system acknowledges the job immediately (<500ms), streams binary payloads directly to secure cloud storage, and uses asynchronous workers to verify integrity and link files to the existing eDMS via API. Coordinators receive real-time, file-by-file delivery tracking with explicit failure logging. 

### **2. Context & Key Terminology** 

###### **Business Context** 

The client provides an electronic document management system (eDMS) for clinical trial management. This new distribution platform acts as an automated ingestion layer that integrates directly with the existing eDMS APIs. 

###### **Data visibility and actions are strictly constrained by a multi-tier permission hierarchy:** 

- [ Hospital ] ──► [ Team ] ──► [ Binder ] ──► [ Folders ] ──► [ Documents ] 

Coordinators must only discover, target, or retrieve files from nodes within this hierarchy for which they hold explicit authorization flags. 

#### **Key Terminologies** 

|**Term**|**Definition**|
|---|---|
|**AuthAPI**|Service managing user profiles, permission flags, and<br>workspace authorization checks.|
|**FileManagementAPI**|Service managing the target directory hierarchy (hospitals,<br>teams, binders, folders) and linking processed files to target<br>nodes.|
|**DocBridgeAPI**|Core batch distribution engine managing Master Jobs, Task<br>records, and presigned URL generation.|
|**Master Job**|The top-level batch container represents a full submission of<br>multiple files across targets.|
|**Task**|The individual unit of execution represents a single file<br>distribution and linkage operation.|
|**Staging Store**|AWS S3 bucket configured with SSE-KMS encryption at rest<br>for secure temporary file landing.|



#### **Related Documentation** 

- Design Requirements: DocBridge (Healthcare System) 

- ADRs: DocBridge ADR (WIP) 

- High-Level Design: DocBridge High Level Architecture 

- User Flow Sequence: <u>User Flow Sequence</u> 

#### **Key Assumptions** 

###### **A. Product & Domain Assumptions (The Business Rules)** 

- **API Ownership & Contracts:** The platform and its core APIs (Auth, File Management, Job Orchestration) are greenfield and internally owned, meaning API contracts are ours to define. 

- **1-to-Many Fan-Out:** Staging a file is decoupled from delivery. A single upload batch can target multiple destination hierarchies (Hospitals -> Teams -> Binders -> Folders) across the system. 

- **Hierarchical Authorization:** Access control is strictly team-based across the organizational hierarchy. Every target lookup, upload, and download request must explicitly validate against team permission boundaries. 

- **Trusted Enterprise Identity:** Users are authorized employees operating within client organizations. However, zero-trust authorization is enforced on every API request. 

###### **B. Architectural & Technical Assumptions (The Execution)** 

- **Perimeter Security Offloading:** Edge security, SSL termination, rate limiting, and DDoS mitigation are handled at the network edge before reaching internal application services. 

- **Direct-to-Storage Ingress:** Payload transfers bypass application servers entirely by streaming binary data directly from client browsers to object storage via short-lived presigned URLs. 

- **Asynchronous Execution:** Metadata registration, object verification, and target folder association are decoupled from the client UI via background message queues to handle network instability gracefully. 

## **3. Job Stories** 

- **Tree Navigation:** When I log into my workspace, I want to browse a permission-accurate folder tree fetched dynamically from the FileManagement API, so that I can only select directories I am authorized to target. 

- **Fast Handshake:** When I initiate a distribution batch of up to 50 GB of files, I want immediate confirmation that the job was accepted (<500ms), so that I can continue working without waiting for transfers to complete. 

- **Secure Direct Streaming:** When my browser transfers large files, I want the payload to stream safely in the background, so that transferring gigabytes of data does not choke or freeze my browser session. 

- **Async Processing & Verification:** When an upload finishes, I want background workers to verify object integrity and link the file to the target directory automatically, so that I don't have to keep my browser open during processing. 

- **On-Demand Retrieval:** When an authorized team member needs a document, I want them to receive a short-lived presigned GET link, so that files are delivered securely directly from edge storage. 



<!-- Start of picture text -->
2. Return IP Adress:<br>15. Upload . 1. Lookup DNS server<br>Binary Data Client Frontend<br>7. Return and 3. Request 11. Request<br>store JWT Auth Login Pre-signed PUT URL<br>Token<br>16.Encrypt<br>$3 Storage 25.Data GETvia —_ Cloudfront < 26. DownloadData<br>Pre-signed<br>url A 4. Forwardy 12. ! Forward<br>6. Return —_ Login Request + PUT URL Request<br>JWT Token<br>- 5. Verify and return<br> Gateway JWT token — ie<br>8. Liles User Application Load Balancer 17. Ping Upload<br>ermissions Completion |<br>10.FileRequest ’ . 13. Update q<br>from Data FileManagement API DocBridge API <—\,), status DocBridge DB<br>user data A<br>9. Verify and return Record and Update 18. Async ;<br>user permissions Data Background Pipeline<br>Auth DB FileManagement DB SQS QueueManager 21. Update<br>Task Status<br>23. Link 20. Consume 19.Check<br>24. Generate S3 Key Task Tasks<br>Pre-Signed GET URL<br>22. Verify Object in $3 Storage bsecL Saleuhs<br>14. Generate Pre-signed PUT URL<br><!-- End of picture text -->

#### **Component Overview** 

|**Component**|**Responsibility**|
|---|---|
|**Edge Perimeter (CloudFront**<br>**+ WAF + ACM)**|SSL termination, rate limiting, IP inspection, and<br>DDoS mitigation for all incoming traffic.|
|**AuthAPI & Cognito**|Manages user credentials, issues JWT tokens, and<br>evaluates user permission flags.|
|**FileManagementAPI**|Serves the folder tree structure Hospital -> Folder<br>and links uploaded S3 keys to directory records.|
|**DocBridgeAPI**|Creates Master Job/Task records in 'pending' state<br>and generates presigned S3 PUT URLs.|
|**Staging S3 Bucket + KMS**|Stores raw incoming binary streams encrypted at rest<br>using server-side KMS encryption.|
|**AWS SQS & ECS Workers**|Asynchronously processes completed uploads,<br>verifies file metadata via HeadObject,and triggers<br>folder linking.|



## **5. User Flow** 

###### **Flow 1: Authentication & Workspace Discovery** 

1. **User Action:** The user logs in with their credentials through the web application. 

2. **System Response:** The system authenticates the user, retrieves their organizational identity, and evaluates their permission flags. 

3. **UI Outcome:** Within 1 second, the workspace renders a personalized, permission-accurate navigation tree showing only the hospitals, teams, binders, and folders the user is authorized to target. 

###### **Flow 2: Job Initiation & Direct Ingress Stream** 

1. **User Action:** The user selects a batch of documents (up to 50 GB), maps each file to one or more target destinations in the hierarchy, and clicks **Distribute** . 

2. **System Response:** The application registers the job metadata and immediately generates secure, direct-to-storage upload authorizations. 

3. **UI Outcome:** In under 500ms, the UI confirms the job has been accepted. The browser streams binary payloads directly to encrypted object storage in the background while keeping the web UI active and unblocked. 

###### **Flow 3: Async Verification & Delivery Pipeline** 

1. **User Action:** The browser finishes streaming the file directly to storage and sends a completion notification ( POST /jobs/:id/uploaded ). 

2. **System Response:** The application updates the job state to pending verification and enqueues a processing message to background workers ( AWS SQS ). 

3. **Background Execution:** Workers consume the message, verify object integrity/KMS encryption in storage ( s3:HeadObject ), and link the file metadata to the target directory in the file management database. 

4. **Outcome:** The file is securely cataloged and associated with the target folder tree asynchronously, allowing background processing without blocking the user's browser or holding connection pools open. 

###### **Flow 4: Recipient File Access & On-Demand Retrieval** 

1. **User Action:** An authorized team member navigates to a destination binder/folder and clicks **Download** on a document. 

2. **System Response:** The system validates the user's READ permissions for that specific node and generates a short-lived, secure access link. 

3. **UI Outcome:** The file streams directly from edge storage to the recipient’s browser immediately without loading application servers. 

## **6. Key Decisions with Architectural Impact** 

##### **1. Three Dedicated Micro-APIs** **<mark>(</mark>** <mark>Auth</mark> **,** <mark>FileManagement</mark> **,** <mark>DocBridge</mark> **<mark>)</mark>** 

- **Decision:** Decompose the system into three domain-bounded microservices <mark>—AuthAPI, FileManagementAPI,</mark> and <mark>DocBridgeAPI—</mark> each backed by an isolated database <mark>(AuthDB, FileManagementDB, DocBridgeDB)</mark> . 

- **Rationale:** Establishes clear domain boundaries and isolates database workloads. Prevents large file orchestration jobs from starving directory tree queries or authentication checks during peak traffic. 

- **Trade-offs:** Introduces inter-service HTTP/gRPC dependencies (e.g. Workers calling <mark>FileManagementAPI)</mark> and increases operational deployment complexity across multiple service codebases. 

##### **2. Direct-to-S3 Upload via Presigned URLs** 

- **Decision:** Bypass application servers entirely during binary data ingest by issuing short-lived S3 Presigned PUT URLs from <mark>DocBridgeAPI</mark> to the client browser. 

- **Rationale:** Keeps application API servers entirely stateless and out of the binary byte-stream path. Guarantees sub-500ms job handshake latency regardless of payload size (e.g., 50 GB uploads). 

- **Trade-offs:** Requires client browsers to manage CORS pre-flight checks <mark>(OPTIONS)</mark> , handle direct S3 PUT retry logic, and gracefully manage client-side network interruptions. 

##### **3. SQS-Driven Asynchronous Worker Pipeline** 

- **Decision:** Decouple binary upload completion from post-processing using an AWS SQS queue consumed by long-polling ECS background workers. 

- **Rationale:** Isolates the client browser's upload completion from database folder-linking and storage integrity checks <mark>(s3:HeadObject)</mark> , ensuring network dropouts during post-processing do not fail the user's transfer. 

- **Trade-offs:** Introduces eventual consistency. Directory tree updates and task completion flags are not instantly visible until the SQS message is fully consumed and processed by the ECS worker. 

##### **4. Dual-Database Pattern (Cognito Identity + Domain** <mark>AuthDB</mark> **<mark>)</mark>** 

- **Decision:** Offload OAuth2/JWT token issuance to AWS Cognito while maintaining a dedicated <mark>AuthDB</mark> for application-specific role/permission mapping. 

- **Rationale:** Relieves application APIs from storing password hashes or managing token signing keys, while keeping fine-grained team/folder permission rules within our own database schema. 

- **Trade-offs:** Requires a two-step auth resolution flow during API requests (validate JWT at API Gateway/Cognito, then query <mark>AuthDB</mark> via <mark>AuthAPI</mark> for team/folder permissions). 

##### **5. Two-Tier Perimeter Security (CloudFront/WAF + API Gateway/ALB)** 

- **Decision:** Enforce edge perimeter protection (CloudFront, ACM, WAF, Shield) before routing traffic to AWS API Gateway and Application Load Balancer. 

- **Rationale:** Offloads DDoS mitigation, IP rate-limiting, and SSL termination at the edge, protecting internal API endpoints and DB connection pools from malicious traffic bursts. 

- **Trade-offs:** Increases network hop latency slightly and requires managing complex CloudFront header forwarding and CORS rules between edge and origin. 

##### **6. Server-Side Encryption with AWS KMS (SSE-KMS)** 

- **Decision:** Enforce mandatory SSE-KMS encryption on all S3 staging buckets during direct binary upload streaming. 

- **Rationale:** Guarantees zero-trust compliance at rest for sensitive enterprise files without requiring client-side encryption overhead or custom encryption pipelines on application servers. 

- **Trade-offs:** Adds AWS KMS API cost per object upload/download and requires worker IAM roles to have explicit <mark>kms:Decrypt</mark> and <mark>kms:GenerateDataKey</mark> permissions. 

##### **7. Client-Initiated Upload Completion Handshake** 

- **Decision:** Rely on the client browser to issue an explicit completion ping <mark>(POST /jobs/:id/uploaded)</mark> to trigger the SQS worker pipeline, rather than listening to S3 Event Notifications <mark>(s3:ObjectCreated)</mark> . 

- **Rationale:** Gives the client application explicit control over when an upload batch is officially declared finished from the UI perspective, simplifying local state tracking. 

- **Trade-offs:** If a client browser crashes or disconnects immediately after S3 finishes uploading but before firing Step 7, an unlinked orphan object may sit in S3 until swept by a cleanup lifecycle policy. 

## **7. Release Scope & Delivery Plan** 

##### **Release 1: Core Distribution Pipeline (MVP)** 

- **Target Date:** August 2026 | **Status:** Planned | **Estimate:** 20 Days 

###### **In Scope (Core Deliverables)** 

- **Auth & Security:** AWS Cognito integration with JWT validation at API Gateway and AuthAPI fine-grained permission evaluation against AuthDB . 

- **Directory Management:** FileManagementAPI dynamic directory tree browsing with permission-checked filtering ( FileManagementDB ). 

- **Ingress Handshake:** DocBridgeAPI job creation, task record tracking, and <500ms S3 presigned PUT URL generation. 

- **Direct Binary Storage:** Direct S3 binary stream ingestion with mandatory server-side encryption via AWS KMS ( SSE-KMS ). 

- **Async Processing:** SQS message queue coupled with long-polling ECS Workers for asynchronous object verification ( s3:HeadObject ) and folder tree metadata linking. 

- **Egress Delivery:** Recipient presigned GET URL generation for direct-from-storage downloads. 

###### **Out of Scope for Release 1** 

- Real-time WebSocket push updates to client browsers (polling/ping mechanism used instead). 

- Multi-region S3 bucket replication or cross-region failover. 

- Automated DLQ (Dead Letter Queue) replay dashboards for failed worker tasks. 

###### **Success Metrics (KPIs)** 

- **Ingress Handshake Latency:** p99 < 500ms for POST /jobs response. 

- **Workspace Tree Latency:** p95 < 1,000ms for initial folder navigation render. 

- **Application Server Offload:** 100% of binary file payload bytes bypass application server instances ( DocBridgeAPI , AuthAPI , FileManagementAPI ). 

- **Pipeline Reliability:** Zero lost task messages in SQS, 100% of failed worker tasks recorded with explicit status in DocBridgeDB . 

##### **Release 2: Advanced Monitoring & Resilience** 

- **Target Date:** TBD | **Status:** Proposed Future Scope 

###### **Candidate Features** 

- **Real-Time UI Updates:** WebSocket push notification channel replacing client polling for worker completion state updates. 

- **Fault Tolerance & DR:** Multi-region S3 bucket cross-region replication (CRR) for high-availability enterprise recovery. 

- **Automated Worker Recovery:** Dead Letter Queue (DLQ) automated retry triggers with exponential backoff for failed SQS worker tasks. 

- **Bulk Download Zip Assembly:** S3 Select / Server-side batch zip generation for multi-file folder downloads. 

###### **Success Metrics (KPIs)** 

- **Real-Time Notification Delivery:** <200ms latency from ECS worker task completion to browser UI push. 

- **Worker Self-Healing:** >95% automated recovery rate on transient S3 verification failures via SQS retries. 

