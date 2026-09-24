import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage } from "./page.ts";

// A deck that hides the progress bar: the renderer writes
// `data-progress="false"` on the `body`.
const page = fakePage([1, 2], { progress: "false" });

before(async () => {
  await import("../src/main.ts");
});

test("a deck can hide the progress bar at load", () => {
  assert.equal(page.body.dataset.progress, "false");
});

test("g then shows the progress bar", () => {
  page.press("g");

  assert.equal(page.body.dataset.progress, "true");
});
