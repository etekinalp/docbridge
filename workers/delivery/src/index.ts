console.log("Starting @docbridge/worker-delivery process...");

export function deliverPayload(destination: string, payload: Record<string, unknown>) {
  return { destination, delivered: true, timestamp: Date.now() };
}