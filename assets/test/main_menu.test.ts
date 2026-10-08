import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage } from "./page.ts";
import { nth } from "./nth.ts";

// The present view of a deck with two slides. Slide 1 has two steps, and the
// tests run in sequence on the same page.
const page = fakePage([2, 1]);
const { body, slides } = page;

before(async () => {
  await import("../src/main.ts");
});

test("m writes data-menu, and the step does not change", () => {
  assert.equal(page.press("m"), true);
  assert.equal(body.dataset.menu, "true");
  assert.equal(nth(slides, 0).dataset.step, "1");
});

test("j and k in the menu move the cursor, and the step does not change", () => {
  page.press("j");
  page.press("j");
  page.press("k");
  assert.equal(nth(slides, 0).dataset.step, "1");
  assert.equal(body.dataset.menu, "true");
});

test("Enter goes to the step of the cursor, and closes the menu", () => {
  page.press("Enter");
  assert.equal(body.dataset.menu, undefined);
  assert.equal(nth(slides, 0).dataset.step, "2");
});

test("Escape closes the menu with no move, and the menu sends no message", () => {
  page.press("s");
  const speaker = nth(page.opened, 0).window;
  const count = speaker.received.length;

  page.press("m");
  page.press("j");
  page.press("Escape");

  assert.equal(body.dataset.menu, undefined);
  assert.equal(nth(slides, 0).dataset.step, "2");
  assert.equal(speaker.received.length, count);
});
