import { describe, it, expect, vi, afterEach } from "vitest";
import { calculateAge, isOldEnough } from "./ageValidation";

describe("Age Validation Utility", () => {
  // Normal cases
  it("Normal_calculateAge_Under13: should calculate age correctly for an 8 year old", () => {
    const mockDate = new Date("2026-03-04T12:00:00Z");
    vi.setSystemTime(mockDate);

    expect(calculateAge(1, 2018)).toBe(8);
    expect(isOldEnough(1, 2018)).toBe(false);
  });

  it("Normal_calculateAge_Over13: should calculate age correctly for a 20 year old", () => {
    const mockDate = new Date("2026-03-04T12:00:00Z");
    vi.setSystemTime(mockDate);

    expect(calculateAge(1, 2006)).toBe(20);
    expect(isOldEnough(1, 2006)).toBe(true);
  });

  // Edge cases
  it("Edge_calculateAge_Exactly13Today: should be exactly 13 if birth month is current month", () => {
    // Assume today is March 2026
    const mockDate = new Date("2026-03-04T12:00:00Z");
    vi.setSystemTime(mockDate);

    // Born March 2013 -> Should be 13 and old enough
    expect(calculateAge(3, 2013)).toBe(13);
    expect(isOldEnough(3, 2013)).toBe(true);
  });

  it("Edge_calculateAge_Almost13: should be 12 if birth month is next month", () => {
    // Assume today is March 2026
    const mockDate = new Date("2026-03-04T12:00:00Z");
    vi.setSystemTime(mockDate);

    // Born April 2013 -> Hasn't had their birthday yet, so they are 12
    expect(calculateAge(4, 2013)).toBe(12);
    expect(isOldEnough(4, 2013)).toBe(false);
  });

  // Extraordinary cases
  it("Extraordinary_calculateAge_FutureDate: should return negative or 0 for unborn", () => {
    const mockDate = new Date("2026-03-04T12:00:00Z");
    vi.setSystemTime(mockDate);

    expect(calculateAge(1, 2030)).toBeLessThan(0);
    expect(isOldEnough(1, 2030)).toBe(false);
  });

  afterEach(() => {
    vi.useRealTimers();
  });
});
