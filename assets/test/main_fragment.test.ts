import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage } from "./page.ts";

// The address holds the fragment of step 2 of slide 2 at load.
const page = fakePage([1, 2], "#2.2");

before(async () => {
  await import("../src/main.ts");
});

test("a fragment at load shows its slide at its step", () => {
  assert.deepEqual(
    page.slides.map((slide) => slide.style.display),
    ["none", "flex"],
  );
  assert.equal(page.slides[1].dataset.step, "2");
  assert.equal(page.body.dataset.view, "present");
});

test("the next key continues from that step", () => {
  page.press("k");

  assert.equal(page.slides[1].dataset.step, "1");
  assert.equal(page.location.hash, "#2.1");
});
