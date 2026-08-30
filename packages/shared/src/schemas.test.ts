import { describe, expect, it } from "bun:test";
import { z } from "zod";

const JobSchema = z.object({
  id: z.string().uuid(),
  status: z.enum(["pending", "processing", "completed", "failed"]),
  createdAt: z.string().datetime(),
});

describe("@docbridge/shared job schema tests", () => {
  it("validates valid job payload", () => {
    const validJob = {
      id: "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
      status: "pending",
      createdAt: new Date().toISOString(),
    };
    expect(JobSchema.safeParse(validJob).success).toBe(true);
  });

  it("rejects invalid status field", () => {
    const invalidJob = {
      id: "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
      status: "unknown_status",
      createdAt: new Date().toISOString(),
    };
    expect(JobSchema.safeParse(invalidJob).success).toBe(false);
  });

  it("rejects invalid date format", () => {
    const invalidJob = {
      id: "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
      status: "pending",
      createdAt: "not-a-date",
    };
    expect(JobSchema.safeParse(invalidJob).success).toBe(false);
  });
});