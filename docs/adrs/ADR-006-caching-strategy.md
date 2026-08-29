
# ADR-006: Authentication & Identity Management 

## ADR-006: Authentication & Identity Management 

### Context 

Our backend consists of three microservices ( **UserAPI** , **PlatformAPI** , **DocBridgeAPI** ) sitting behind an API Gateway. While **UserAPI** handles app-specific permissions, organization roles, and access rules, we need a secure way to handle core identity: password hashing, resets, Multi-Factor Authentication (MFA), and issuing JWT tokens. 

We also need to decide where token verification happens. If every microservice manually checks JWT signatures on every single HTTP request, we waste CPU and duplicate code everywhere. But if we don't verify tokens at the front door, bad requests reach our internal network. 

### Decision Required 

Which Identity Provider (IdP) should we use for user authentication, and where should token verification happen in our pipeline? 

### Options Evaluated 

###### **Option 1: Build a Custom Auth Engine inside UserAPI** 

- **Pro:** Full control over user data and token logic without any vendor lock-in. 

- **Con:** High security risk. Our team becomes solely responsible for password encryption (bcrypt/Argon2), MFA, rate-limiting login attempts, and handling GDPR/compliance for storing user credentials. 

###### **Option 2: Managed SaaS Provider (e.g. Auth0)** 

- **Pro:** Easy out-of-the-box setup with a ready-made login UI and built-in compliance. 

- **Con:** Monthly Active User (MAU) pricing gets expensive fast as we scale, and it introduces an external dependency outside our AWS cloud setup. 

###### **Option 3: AWS Cognito + API Gateway Edge Verification** 

- **Pro:** Native to AWS with near-zero base cost at our scale. AWS handles password security, MFA, and token signing out of the box. The API Gateway validates the JWT right at the edge before traffic ever touches our microservices. 

- **Con:** Customizing Cognito's built-in login UI has some limits, requiring schema mapping for custom attributes. 

### Decision 

###### **Option 3: AWS Cognito + API Gateway Edge Verification** 

### Rationale & Defense 

- **Delegated Security:** Let AWS handle credential storage, password hashing, MFA, and brute-force protection. It keeps our code simple and avoids the heavy liability of managing sensitive password data in-house. 

- **Front-Door Verification:** Checking JWT tokens at the API Gateway blocks expired, fake, or invalid requests right at the perimeter. Bad traffic gets rejected instantly, saving compute resources and keeping our internal APIs safe. 

- **Cleaner Microservices:** Because the Gateway validates the token at the entry point, downstream services ( **UserAPI** , **PlatformAPI** , **DocBridgeAPI** ) don't need to re-verify JWT signatures on every request. The Gateway simply passes trusted user headers (like **user_id** and **email** ) down to the internal services, keeping our backend code clean and fast. 

**Ratified by:** Emre Tekinalp 

**Date:** Aug 14, 2026