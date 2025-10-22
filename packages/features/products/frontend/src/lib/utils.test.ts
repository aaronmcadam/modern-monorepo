import { expect, test } from "vitest";
import { formatPrice } from "./utils";

test("formats cents to dollars correctly", () => {
  expect(formatPrice(1000)).toBe("$10.00");
  expect(formatPrice(99)).toBe("$0.99");
  expect(formatPrice(0)).toBe("$0.00");
});

test("handles large amounts", () => {
  expect(formatPrice(123456)).toBe("$1234.56");
});

test("throws error for negative prices", () => {
  expect(() => formatPrice(-100)).toThrow("Price cannot be negative");
});
