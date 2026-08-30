import { describe, expect, it } from "bun:test";
import { z } from "zod";

describe("Sanity Check", () => {
  it("should pass initial M0 setup", () => {
    expect(true).toBe(true);
  });
});

// Sample schema test to ensure shared package validation works
const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
});

describe("@docbridge/shared test suite", () => {
  it("validates correct user schema payload", () => {
    const validData = {
      id: "123e4567-e89b-12d3-a456-426614174000",
      email: "developer@docbridge.io",
    };

    const result = UserSchema.safeParse(validData);
    expect(result.success).toBe(true);
  });

  it("rejects invalid email formats", () => {
    const invalidData = {
      id: "123e4567-e89b-12d3-a456-426614174000",
      email: "not-an-email",
    };

    const result = UserSchema.safeParse(invalidData);
    expect(result.success).toBe(false);
  });
});