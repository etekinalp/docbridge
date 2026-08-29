# ADR-013: Database-Level Delivery Idempotency 

## ADR-013: Database-Level Delivery Idempotency & Partial Unique Constraints 

### Context 

AWS SQS guarantees at-least-once message delivery, meaning background workers may occasionally receive and process duplicate task execution messages. Additionally, mapping files to binder roots produces NULL folder_id values. Standard SQL UNIQUE constraints treat NULL != NULL, allowing duplicate destinations to be inserted silently. 

### Decision Required 

How do we prevent duplicate destination mappings and redundant file ingestion handling across distributed workers? 

### Options Evaluated 

###### **Option 1: Distributed Redis Locking** 

- **Pro** : Blocks concurrent worker execution before touching primary storage or APIs. 

- **Con** : Introduces an extra Redis infrastructure dependency and risk of stale locks on worker crashes. 

###### **Option 2: Database Partial Unique Indexes & ON CONFLICT Execution** 

- **Pro** : Native PostgreSQL enforcement using partial unique indexes (WHERE folder_id IS NOT NULL / WHERE folder_id IS NULL) and ON CONFLICT (source_task_id) DO NOTHING. 

- **Con** : Requires handling database constraint violations gracefully within API transaction blocks. 

### Decision 

###### **Option 2: Database Partial Unique Indexes & ON CONFLICT Execution.** 

### Rationale & Defense 

- **Guaranteed Idempotency:** The source_task_id UNIQUE constraint on platform_db.documents ensures retried worker requests return existing records without creating duplicate files. 

- **Zero Overhead:** Eliminates the need for external caching clusters by relying on relational ACID guarantees. 

**Ratified by: Date:** Emre Tekinalp Aug 25, 2026 