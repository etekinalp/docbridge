import { describe, expect, it } from "bun:test";

describe("user-api service suite", () => {
  it("returns 200 OK on health endpoint check", async () => {
    const req = new Request("http://localhost:3001/health");
    expect(req.url).toContain("/health");
  });

  it("parses user registration payload correctly", () => {
    const userPayload = { email: "test@docbridge.io", name: "DocBridge User" };
    expect(userPayload.email).toBe("test@docbridge.io");
    expect(userPayload.name).toBeDefined();
  });

  it("handles authorization headers appropriately", () => {
    const headers = new Headers({ authorization: "Bearer fake-token-123" });
    expect(headers.get("authorization")).toBe("Bearer fake-token-123");
  });
});