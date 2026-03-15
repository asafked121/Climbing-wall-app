import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { api } from "./api";

describe("api utility", () => {
  beforeEach(() => {
    global.fetch = vi.fn();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  // --- Normal Cases ---
  it("GET request_NormalCase_returnsDataSuccessfully", async () => {
    // Arrange
    const mockData = { id: 1, name: "Test" };
    (global.fetch as import("vitest").Mock).mockResolvedValueOnce({
      ok: true,
      headers: new Headers({ "content-type": "application/json" }),
      json: async () => mockData,
    });

    // Act
    const result = await api.get("/test");

    // Assert
    expect(global.fetch).toHaveBeenCalledWith(
      "/api/test",
      expect.objectContaining({
        method: "GET",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
      }),
    );
    expect(result).toEqual(mockData);
  });

  it("POST request_NormalCase_sendsDataAndReturnsResponse", async () => {
    // Arrange
    const payload = { title: "New Route" };
    const mockResponse = { success: true };
    (global.fetch as import("vitest").Mock).mockResolvedValueOnce({
      ok: true,
      headers: new Headers({ "content-type": "application/json" }),
      json: async () => mockResponse,
    });

    // Act
    const result = await api.post("/test", payload);

    // Assert
    expect(global.fetch).toHaveBeenCalledWith(
      "/api/test",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify(payload),
        credentials: "include",
        headers: { "Content-Type": "application/json" },
      }),
    );
    expect(result).toEqual(mockResponse);
  });

  // --- Edge Cases ---
  it("request_EmptyStringPayload_handlesCorrectly", async () => {
    // Arrange
    const payload = "";
    (global.fetch as import("vitest").Mock).mockResolvedValueOnce({
      ok: true,
      headers: new Headers({ "content-type": "application/json" }),
      json: async () => ({}),
    });

    // Act
    await api.post("/test", payload);

    // Assert
    expect(global.fetch).toHaveBeenCalledWith(
      "/api/test",
      expect.objectContaining({
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
      }),
    );
  });

  it("request_NoContentTypeHeader_handlesEmptyResponseGracefully", async () => {
    // Arrange
    (global.fetch as import("vitest").Mock).mockResolvedValueOnce({
      ok: true,
      headers: new Headers(), // No content-type
      status: 204,
    });

    // Act
    const result = await api.delete("/test");

    // Assert
    expect(result).toBeUndefined();
  });

  // --- Extraordinary Cases ---
  it("request_NetworkFailure_throwsAppropriateError", async () => {
    // Arrange
    (global.fetch as import("vitest").Mock).mockRejectedValueOnce(new Error("Network offline"));

    // Act / Assert
    await expect(api.get("/test")).rejects.toThrow(
      "Network error: Network offline",
    );
  });

  it("request_ApiErrorResponse_throwsApiErrorWithStatus", async () => {
    // Arrange
    const errorData = { detail: "Unauthorized access" };
    (global.fetch as import("vitest").Mock).mockResolvedValueOnce({
      ok: false,
      status: 401,
      statusText: "Unauthorized",
      headers: new Headers({ "content-type": "application/json" }),
      json: async () => errorData,
    });

    // Act
    try {
      await api.get("/secure-data");
      expect.fail("Should have thrown an ApiError");
    } catch (err) {
      const e = err as { name: string; status: number; message: string; data: unknown };
      // Assert
      expect(e.name).toBe("ApiError");
      expect(e.status).toBe(401);
      expect(e.message).toBe("Unauthorized access");
      expect(e.data).toEqual(errorData);
    }
  });

  it("request_massivePayload_handlesCorrectlyWithoutCrash", async () => {
    // Arrange
    const massiveString = "A".repeat(100000);
    const payload = { heavy: massiveString };
    (global.fetch as import("vitest").Mock).mockResolvedValueOnce({
      ok: true,
      headers: new Headers({ "content-type": "application/json" }),
      json: async () => ({ success: true }),
    });

    // Act
    const result = await api.post("/test", payload);

    // Assert
    expect(global.fetch).toHaveBeenCalledWith(
      "/api/test",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify(payload),
        credentials: "include",
        headers: { "Content-Type": "application/json" },
      }),
    );
    expect(result).toEqual({ success: true });
  });

  it("request_nullPayload_handlesCorrectly", async () => {
    // Arrange
    const payload = null;
    (global.fetch as import("vitest").Mock).mockResolvedValueOnce({
      ok: true,
      headers: new Headers({ "content-type": "application/json" }),
      json: async () => ({ success: true }),
    });

    // Act
    const result = await api.post("/test", payload);

    // Assert
    expect(global.fetch).toHaveBeenCalledWith(
      "/api/test",
      expect.objectContaining({
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
      }),
    );
    expect(result).toEqual({ success: true });
  });
});
