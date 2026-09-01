console.log("Starting @docbridge/worker-delivery process...");

export function deliverPayload(destination: string, payload: Record<string, unknown>) {
  void payload;
  return { destination, delivered: true, timestamp: Date.now() };
}