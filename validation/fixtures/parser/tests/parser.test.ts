import { test, expect } from "vitest";
import { parseCsvRow } from "../src/parser";

test("empty string returns empty array", () => {
  expect(parseCsvRow("")).toEqual([]);
});

test("single field", () => {
  expect(parseCsvRow("hello")).toEqual(["hello"]);
});

test("multiple fields", () => {
  expect(parseCsvRow("a,b,c")).toEqual(["a", "b", "c"]);
});

// Missing tests: quoted fields, escaped quotes, trailing comma,
// unclosed quote, whitespace handling, mixed quoted/unquoted.
