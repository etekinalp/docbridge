const port = Number(process.env.PORT) || 3003;

Bun.serve({
  hostname: "0.0.0.0",
  port,
  fetch(req) {
    const url = new URL(req.url);
    if (url.pathname === "/health" || url.pathname === "/health/ready") {
      return new Response(
        JSON.stringify({ status: "ok", service: "docbridge-api" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }
    return new Response("DocBridge API", { status: 200 });
  },
});

console.log(`docbridge-api running on port ${port}`);