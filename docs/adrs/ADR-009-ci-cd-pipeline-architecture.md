# ADR-009: Worker Database Authorization & Access 

## ADR-009: Worker Database Authorization & Access Strategy 

### Context 

Background workers need to update task statuses, record delivery logs, and mark files as available in the database. Giving distributed background workers direct, full-access credentials to the primary database introduces security risks, credential management headaches, and database connection pool exhaustion if hundreds of workers scale up simultaneously. 

### Decision Required 

How do background workers securely authenticate and access the database to update job and file statuses without exposing database credentials or risking connection pool overload? 

### Options Evaluated 

###### **Option 1: Direct Database Connections via Secrets Manager** 

- **Pro 1 (Simple Setup):** Quick to implement because workers connect straight to PostgreSQL using credentials fetched from AWS Secrets Manager. 

- **Pro 2 (Low Latency):** Directly executes SQL queries without passing through an extra software layer or internal API network hop. 

- **Con 1 (Security Exposure):** Exposing database connection strings and table access directly to background workers expands the attack surface if a worker node is compromised. 

- **Con 2 (Connection Exhaustion):** If hundreds of workers spin up at once to handle a massive file batch, they can quickly max out PostgreSQL connection limits unless strictly managed. 

###### **Option 2: Internal API Access via Service Tokens** 

- **Pro 1 (Strong Security & Isolation):** Workers never talk to the database directly. They authenticate with short-lived service tokens and call internal **docbridge-api** endpoints, keeping DB credentials locked inside the core API service. 

- **Pro 2 (Centralized Connection Control):** The core API handles all database connection pooling centrally through RDS Proxy, protecting PostgreSQL from sudden worker spikes. 

- **Con 1 (Slight Latency Overhead):** Calling an API endpoint adds a tiny network delay compared to running a raw database query directly. 

- **Con 2 (Extra API Routes):** Requires creating and maintaining dedicated internal API 

endpoints specifically for worker status updates. 

###### **Option 3: AWS IAM Database Authentication with RDS Proxy** 

- **Pro 1 (Passwordless Security):** Uses short-lived IAM tokens instead of database passwords, eliminating stored credential management completely. 

- **Pro 2 (Managed Connection Pooling):** AWS RDS Proxy sits between workers and PostgreSQL, automatically pooling and re-using database connections. 

- **Con 1 (Vendor Lock-in):** Ties database authentication tightly to AWS IAM infrastructure, making local testing or multi-cloud deployment harder. 

- **Con 2 (Direct Query Risk):** Workers still hold direct database access permissions, meaning buggy or compromised worker code could execute unsafe queries against tables. 

### Decision 

###### **Option 2: Internal API Access via Service Tokens** 

### Rationale & Defense 

- **Direct Match to Requirements:** Option 2 leverages our existing AWS Cognito authentication setup to isolate background workers completely from the database. Workers attach their token to the HTTP header, allowing the API to verify access instantly using Cognito's public key without hitting the database for authentication checks. 

- **Mitigated Risk:** We accept the small network delay of calling an internal API because it gives us centralized control over database connections via RDS Proxy, preventing worker bursts from crashing PostgreSQL. 

- **Upgrade/Migration Path:** If we ever switch identity providers from Cognito to another service (like Auth0 or Okta), we only need to update the public key verification URL on our API endpoints, our background worker logic and database structure stay completely untouched. 

**Ratified by:** Emre Tekinalp 

**Date:** Aug 21, 2026 