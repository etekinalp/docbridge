# ADR-012: Database RLS for Multi-Tenant Auth 

## ADR-012: Database Row-Level Security (RLS) for Multi-Tenant Authorization 

### Context 

The platform manages multi-tenant clinical trial documents across organizational boundaries. Users must only discover or access directories and documents within teams where they hold explicit authorization. Relying solely on application-level filtering creates risks of authorization bypass if an API developer forgets to append team membership checks to a query. 

### Decision Required 

How do we enforce strict multi-tenant data isolation at the database layer for hierarchical workspace resources? 

### Options Evaluated 

###### **Option 1: Application-Level Authorization (Query Filtering)** 

- **Pro** : Simple to implement in ORMs or standard SQL queries. 

- **Con** : Single point of failure in code; missing a **WHERE team_id = ...** filter in a new endpoint exposes data across tenants. 

###### **Option 2: PostgreSQL Row-Level Security (RLS)** 

- **Pro** : Enforces zero-trust database isolation at the engine level, automatically filtering queries based on session attributes even if raw application SQL omits checks. 

- **Con** : Slightly increases database engine overhead and complicates local database unit testing. 

###### **Option 3: Schema-Per-Tenant Isolation** 

- **Pro** : Complete logical isolation of data schemas. 

- **Con** : Heavy migration management overhead for multi-region teams and complex connection pooling. 

### Decision 

###### **Option 2: PostgreSQL Row-Level Security (RLS) on binders and documents tables.** 

### Rationale & Defense 

- **Defense-in-Depth:** RLS guarantees that even if application API handlers fail to validate permissions, PostgreSQL restricts rows to authorized users using active session parameters. 

- **Mitigated Risk:** Local testing complexity is handled in CI/CD by executing integration test suites with specific tenant role contexts. 

**Ratified by:** Emre Tekinalp 

**Date:** Aug 25, 2026 