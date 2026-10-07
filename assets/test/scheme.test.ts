import { test } from "node:test";
import assert from "node:assert/strict";
import { fromAddress, next } from "../src/scheme.ts";

test("next returns the other variant of the variant that the window shows", () => {
  assert.equal(next(null, false), "dark");
  assert.equal(next(null, true), "light");
  assert.equal(next("light", true), "dark");
  assert.equal(next("dark", false), "light");
});

test("fromAddress returns a variant, or null for a value that is not a variant", () => {
  assert.equal(fromAddress("light"), "light");
  assert.equal(fromAddress("dark"), "dark");
  for (const value of [null, "", "Dark", "sepia"]) {
    assert.equal(fromAddress(value), null, String(value));
  }
});
