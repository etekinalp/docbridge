console.log("Starting @docbridge/worker-ws process...");

export function broadcastWsMessage(channel: string, event: string) {
  return { channel, event, sent: true };
}