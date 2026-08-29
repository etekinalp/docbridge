# ADR-004: File Transfer Path & Presigned URLs 

## ADR-004: File Transfer Path & Presigned URLs 

### Context 

Our system allows users to upload documents, which can sometimes be very large (up to 1 GB or large batches of files). We need a secure and efficient way to move these files from the client's frontend browser into our AWS S3 storage buckets. 

If we pass a 1 GB file directly through our API Gateway and into the **DocBridgeAPI** or **PlatformAPI** containers, it will tie up server RAM, max out network bandwidth, and likely cause HTTP timeouts. This would act as a "noisy neighbor" slowing down the rest of the application. 

### Decision Required 

How should we route and authorize file uploads from the frontend client to our AWS S3 storage to ensure maximum performance and avoid overloading our API servers? 

### Options Evaluated 

###### **Option 1: Proxy Upload (Through DocBridgeAPI )** 

- **Pro:** Simpler initial development. The frontend just sends a standard HTTP POST request with the file, keeping all upload logic unified inside our existing API structure. 

- **Con:** Creates a massive system bottleneck. Passing 1 GB files through the API will rapidly max out container RAM, tie up network connections, and trigger HTTP timeouts. Concurrent uploads would quickly crash the server, causing cascading failures. 

###### **Option 2: Direct-to-S3 via Presigned URLs** 

- **Pro:** The most efficient, highly scalable approach. By offloading the heavy binary transfer directly to AWS S3, we completely bypass the API bottleneck. The API uses virtually zero RAM, and S3 handles the massive bandwidth effortlessly. 

- **Con:** Introduces additional architectural and client-side complexity. The frontend must first request the URL, execute the S3 upload, and then ideally notify the backend when it finishes (or the backend must rely on an asynchronous S3 event trigger). 

### Decision 

###### **Option 2: Direct-to-S3 via Presigned URLs** 

#### Rationale & Defense 

- **Direct Match to Requirements:** This option completely eliminates memory, CPU, and bandwidth bottlenecks on our backend API servers. By keeping heavy binary traffic out of **DocBridgeAPI** , we prevent server crashes, memory leaks, and the need for expensive, emergency server scaling or manual cache clearing. The upload pipeline remains resilient even when handling massive 1 GB files. 

- **Mitigated Risk:** We accept the extra frontend development complexity required to manage the presigned URL lifecycle (handling JWT authorization to fetch presigned **PUT** for uploads or **GET** for downloads, progress tracking, and error handling). This upfront effort is well worth the trade-off, as it guarantees a smooth user experience and complete system isolation. 

- **Scalability & Security:** AWS S3 handles high-concurrency binary transfers natively. Utilizing short-lived presigned URLs ensures that files remain strictly encrypted and private in S3 while granting temporary access only to authorized, authenticated users. 

**Ratified by: Date:** Emre Tekinalp Aug 14, 2026 