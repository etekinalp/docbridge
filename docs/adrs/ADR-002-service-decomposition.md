# ADR-002: Service Decomposition Architecture 

## ADR-002: Service Decomposition Architecture 

### Context 

Our application handles three distinct functional domains: User Identity and Authorization ( **UserAPI** ), Workspace and Document Metadata ( **PlatformAPI** ), and Asynchronous Upload Orchestration and Task Tracking ( **DocBridgeAPI** ). 

These workloads have fundamentally different runtime characteristics. User authentication requires ultra-low latency, document metadata queries are read-heavy and job orchestration/task queues are bursty and resource-intensive. A failure or traffic surge in task processing (e.g. thousands of concurrent file uploads) must not degrade core login or workspace navigation performance. 

### Decision Required 

How should we structure and deploy our backend application architecture to ensure domain separation, fault isolation, and independent scalability? 

### Options Evaluated 

###### **Option 1: Single Monolithic Architecture** 

- **Pro:** Lower initial operational overhead. Single codebase, single deployment pipeline, and simple in-memory function calls between modules instead of network requests. 

- **Con:** Creates a Single Point of Failure ( **SPOF** ) A memory leak or crash in heavy file/task processing takes down login ( **Auth** ) and workspace navigation ( **FileManagement** ). Code maintainability degrades over time as features accumulate in one repository. 

###### **Option 2: Microservices Architecture (3 Independent Services: UserAPI , PlatformAPI , DocBridgeAPI )** 

- **Pro:** Complete fault isolation and domain separation: a failure in background job processing ( **DocBridgeAPI** ) will never impact core user login or folder navigation. Allows each service to compute independently based on load. 

- **Con:** Higher operational overhead: requires managing three deployment pipelines, separate container configurations, and inter-service network calls. 

###### **Option 3: Modular Monolith** 

- **Pro:** Keeps code clean and well-structured with strict folder/module boundaries while maintaining the simplicity of a single deployable artifact. 

- **Con:** Still shares a single runtime process: a fatal unhandled error or CPU spike in task processing affects all modules, failing to satisfy our fault isolation requirement under heavy load. 

### Decision 

###### **Option 2: Microservices Architecture** 

#### **Rationale & Defense** 

- **Direct Match to Requirements:** This option eliminates Single Points of Failure (SPOF) across backend domains. By decoupling **DocBridgeAPI** from **UserAPI** and **PlatformAPI** , any runtime crash or memory overload during heavy background task processing will not interrupt user login or folder navigation. 

- **Mitigated Risk:** We accept the initial development and deployment complexity of managing three separate services. The operational effort is justified by the requirement for fault isolation and service stability when handling sensitive data. 

- **Upgrade/Migration Path:** Operating separate services allows us to scale, update, and modify each domain independently. If **DocBridgeAPI** requires additional compute capacity during high-volume upload bursts, its container resources can be scaled on ECS without altering or redeploying the **UserAPI** or **PlatformAPI** infrastructure. 

**Ratified by:** Emre Tekinalp 

**Date:** Aug 14, 2026 