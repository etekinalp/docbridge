# ADR-003: Database Isolation & Topology 

## ADR-003: Database Isolation & Topology 

### Context 

To support our three microservices ( **UserAPI** , **PlatformAPI** , and **DocBridgeAPI** ), we must establish clear data ownership boundaries. Cross-service database joins (e.g., querying user permissions directly inside a document query) couple microservices at the schema level and break service isolation. 

Each service has distinct database access patterns: **UserAPI** requires low-latency relational queries for accounts and roles **PlatformAPI** handles read-heavy queries for hierarchical 

workspace metadata and **DocBridgeAPI** performs bursty transactional writes for background job and task tracking and WebSocket subscription states. We need an architecture that enforces strict data isolation while keeping database management simple and cost-effective. 

### Decision Required 

How do we physically and logically structure our PostgreSQL database topology to enforce strict data ownership across our three microservices? 

### Options Evaluated 

###### **Option 1: Single Database Instance, Single Shared Schema** 

- **Pro:** Simplest initial setup single connection string and effortless cross-table queries. 

- **Con:** Zero logical data isolation. Allows microservices to bypass API boundaries and query each other's tables directly, coupling database schemas and creating a single point of failure. 

###### **Option 2: Single Database Instance with 3 Isolated Logical Databases (Multi-AZ)** 

- **Pro:** Enforces strict logical data isolation using separate database credentials and permissions per microservice. Cost-effective hosting on a single AWS RDS instance backed by Multi-AZ high availability to prevent hardware failure. 

- **Con:** Shares underlying physical compute (CPU/RAM). High noisy-neighbor traffic on one database can temporarily impact query performance on the others. 

###### **Option 3: 3 Independent Physical Database Instances** 

- **Pro:** Maximum physical fault isolation, zero resource competition, and independent CPU/RAM hardware scaling per database. 

- **Con:** High operational baseline cost (3x AWS RDS charges) and unnecessary management overhead for our current workload volume. 

### Decision 

###### **Option 2: Single Database Instance with 3 Isolated Logical Databases (Multi-AZ)** 

#### Rationale & Defense 

- **Direct Match to Requirements:** This option provides the most cost-efficient way to ensure each microservice has a completely isolated database, guaranteeing that they cannot interfere with or touch each other's data. By configuring the AWS RDS instance with Multi-AZ (Multi-Availability Zone) backups, we effectively eliminate the physical Single Point of Failure (SPOF). 

- **Mitigated Risk:** While the setup and internal networking are slightly more complex than a shared schema, the trade-off is absolutely worth it for the strict data boundary stability and cost savings. 

- **Upgrade/Migration Path:** If the load or traffic on any single database (like **DocBridgeDB** ) scales up in the future and requires more dedicated compute power, we can easily extract that specific logical database, migrate it to its own physical Multi-AZ database server, and scale horizontally without rewriting our application code. 

**Ratified by:** Emre Tekinalp 

**Date:** Aug 14, 2026 