ADR-008: Live Updates Transport Strategy 

## ADR-008: Live Updates Transport Strategy 

### Context 

When users submit large file batches, they need to see progress bars and status changes in real time on their dashboard (e.g. pending, in-progress, completed, or failed). Updating the user interface requires a way for our backend to notify the frontend when background workers finish processing tasks, without requiring the user to manually refresh their browser page. 

### Decision Required 

Which transport protocol do we use to deliver real-time job and task progress updates from the backend to the user's browser? 

### Options Evaluated 

###### **Option 1: Polling (Short / Long Polling)** 

- **Pro 1 (Development Speed):** Very simple to set up on both frontend and backend. The frontend just calls a standard REST API endpoint on a timer (like every 3-5 seconds) to ask for current progress. 

- **Pro 2 (No Special Infrastructure):** Uses basic HTTP requests, so you don't need persistent connection managers, special API gateways, or state-tracking tools. 

- **Con 1 (Wasted Server Load):** Hundreds of users checking in every few seconds generates thousands of unnecessary database queries and API calls, even when nothing has changed. 

- **Con 2 (Update Lag):** Updates aren't instant. Users have to wait until the next timer tick to see progress changes on their dashboard. 

###### **Option 2: WebSockets** 

- **Pro 1 (Instant Two-Way Communication):** Opens a continuous, persistent channel between the browser and backend. Updates land on the user's screen instantly, and the user can also send actions back instantly (like clicking "Cancel Job") over the exact same connection. 

- **Pro 2 (Low Network Overhead per Update):** Once the connection is open, pushing progress messages uses tiny data packets compared to constantly opening and closing full HTTP requests. 

- **Con 1 (Higher Infrastructure Complexity):** Requires setting up persistent connection tracking (like AWS API Gateway WebSockets or a Redis Pub/Sub backplane) so background workers know which connected socket belongs to which user. 

- **Con 2 (Reconnection Logic Needed):** If a user's Wi-Fi cuts off, you need custom code 

on the frontend to automatically reconnect, re-authenticate, and fetch any progress updates missed while offline. 

###### **Option 3: Server-Sent Events (SSE)** 

- **Pro 1 (Native Browser Support & Reconnects):** Built into standard HTTP with automatic reconnect logic handled by the browser out of the box, making it easier to write than WebSockets. 

- **Pro 2 (Lightweight for Pushes):** Works well for simple server-to-client streaming where you only need to push progress updates. 

- **Con 1 (One-Way Only):** Data can only flow from server to browser. If a user wants to cancel a job or trigger an action, they have to send a separate HTTP REST request. 

- **Con 2 (Connection Limits & Scaling):** HTTP browsers cap open SSE streams to 6 per domain, and keeping HTTP connections hanging open on serverless backends can complicate scaling or cost tracking compared to dedicated WebSocket routes. 

### Decision 

###### **Option 2: WebSockets** 

### Rationale & Defense 

- **Direct Match to Requirements:** WebSockets (Option 2) give us instant, real-time feedback for the user dashboard. As background workers complete file deliveries, progress updates show up on the user's screen with zero lag. Because WebSockets support two-way communication, users can also send commands back over the same connection such as clicking "Cancel Batch" without opening extra HTTP connections. 

- **Mitigated Risk:** We accept the added setup complexity by offloading connection management to AWS API Gateway WebSockets, which keeps track of active user connection IDs in DynamoDB or Redis. To handle Wi-Fi drops or lost connections, we write automatic retry logic on the frontend so the browser quietly reconnects and fetches any missed status updates from the database. 

- **Upgrade/Migration Path:** If traffic grows massively across multiple regions, we can place a Redis Pub/Sub or AWS EventBridge message channel behind our WebSocket gateway. This allows workers to push live status updates to thousands of connected users simultaneously without altering our main API structure or changing the frontend interface. 

**Ratified by:** Emre Tekinalp 

**Date:** Aug 21, 2026 