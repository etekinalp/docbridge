# ADR-001: Public Ingress & Edge 

## ADR-001: Public Ingress & Edge Perimeter 

### Context 

Our web application (React SPA) sends HTTP requests to backend microservices ( **UserAPI ,** 

**DocBridgeAPI , PlatformAPI** ) running in private container networks. Public entry points are exposed to threats like DDoS attacks and credential abuse. All traffic must enforce HTTPS, inspect/rate-limit incoming requests, reject unauthenticated JWT tokens before hitting internal services, and keep application containers isolated from direct public exposure. 

### Decision Required 

How do we protect, authenticate, and route public HTTP traffic from the web client into our private internal services? 

### Options Evaluated 

###### **Option 1: Single Public Application Load Balancer (ALB)** 

- **Pro:** Simplest setup with the lowest baseline monthly cost and zero extra routing hops. 

- **Con:** Exposes the ALB directly to the internet, lacks edge DDoS/bot protection (WAF) and forces JWT validation to happen inside backend application containers. 

###### **Option 2: Edge Perimeter (CloudFront + WAF) > API Gateway > Internal ALB** 

- **Pro:** Complete defense-in-depth: traffic is sanitized at the edge (CloudFront/WAF), JWT tokens are authenticated before reaching private subnets (API Gateway), and backend containers remain entirely unexposed to public IPs. 

- **Con:** Slightly higher per-request cost and adds configuration surface with two routing layers. 

###### **Option 3: Self-Hosted NGINX / Kong Proxy on EC2** 

- **Pro:** Maximum control, customizability, and portability across clouds or local environments without AWS lock-in. 

- **Con:** High baseline compute costs (paying for 24/7 EC2 instances) and heavy operational overhead (your team must patch, scale, and maintain proxy servers). 

###### **Option 4: Direct Serverless (Lambda Function URLs)** 

- **Pro:** Easiest operational model with zero server management and automatic pay-per-use scaling. 

- **Con:** Bypasses central edge security, lacks native WAF/rate-limiting integration, and splits auth logic across separate functions. 

### Decision 

###### **Option 2:  Edge Perimeter (CloudFront + WAF) > API Gateway > Internal ALB** 

##### **Rationale & Defense** 

- **Direct Match to Requirements:** This option satisfies all security requirements by scrubbing traffic at the border via CloudFront, WAF, and Shield. API Gateway handles JWT verification at the edge, ensuring unauthenticated or malicious requests are rejected before ever reaching the private network or waking up backend containers. 

- **Mitigated Risk:** We accept the slight added cost and configuration overhead of multiple routing layers because our domain handles sensitive data. Defense-in-depth takes priority over minimizing initial configuration steps. 

- **Upgrade/Migration Path:** CloudFront and API Gateway scale automatically with zero infrastructure management. If traffic grows 100 times, backend microservices can be split into dedicated target groups or new ECS services behind the internal ALB without modifying the client-facing edge URL or security policies. 

**Ratified by:** Emre Tekinalp 

**Date:** Aug 13, 2026 