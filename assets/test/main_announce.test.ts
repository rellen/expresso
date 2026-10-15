import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage } from "./page.ts";

// A deck of a slide with one step and a slide with two steps. The renderer
// gives the page of each step a name for a screen reader in `aria-label`. The
// tests run in sequence on the same page.
const page = fakePage([1, 2]);
[
  "Slide 1 of 2: Hello",
  "Slide 2 of 2, step 1 of 2",
  "Slide 2 of 2, step 2 of 2",
].forEach((label, index) =>
  page.pages[index]?.setAttribute("aria-label", label),
);

before(async () => {
  await import("../src/main.ts");
});

test("the live region is empty at load, and the progress bar is at 0", () => {
  assert.equal(page.announce.textContent, "");
  assert.equal(page.progress.getAttribute("aria-valuenow"), "0");
});

test("a move to a slide gives its name and its step", () => {
  page.press("j");

  assert.equal(page.announce.textContent, "Slide 2 of 2, step 1 of 2");
});

test("a move inside a slide gives the step only", () => {
  page.press("j");

  assert.equal(page.announce.textContent, "Step 2 of 2");
  assert.equal(page.progress.getAttribute("aria-valuenow"), "100");
});

test("a move back to a slide of one step gives its name", () => {
  page.press("Home");

  assert.equal(page.announce.textContent, "Slide 1 of 2: Hello");
  assert.equal(page.progress.getAttribute("aria-valuenow"), "0");
});

test("a key that does not move writes nothing new", () => {
  page.press("x");

  assert.equal(page.announce.textContent, "Slide 1 of 2: Hello");
});
