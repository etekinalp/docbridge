console.log("Starting @docbridge/worker-fanout process...");

export function processFanoutJob(jobId: string) {
  return { jobId, status: "PROCESSED", timestamp: Date.now() };
}