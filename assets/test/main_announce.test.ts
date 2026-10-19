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
// The page of the last step of each slide also holds the name of its slide
// with no step, for the overview.
page.pages[0]?.setAttribute("data-overview-label", "Slide 1 of 2: Hello");
page.pages[2]?.setAttribute("data-overview-label", "Slide 2 of 2");

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

test("o tells that the overview opens, and names the selected slide with no step", () => {
  page.press("o");

  assert.equal(page.announce.textContent, "Overview. Slide 1 of 2: Hello");
});

test("a key that selects a different slide in the overview names that slide", () => {
  page.press("j");

  assert.equal(page.announce.textContent, "Slide 2 of 2");
  assert.equal(page.location.hash, "#1.1");
});

test("a key that does not change the selection in the overview writes nothing new", () => {
  page.announce.textContent = "";
  page.press("End");

  assert.equal(page.announce.textContent, "");
});

test("Escape closes the overview with no move, and gives the position again", () => {
  page.press("Escape");

  assert.equal(page.announce.textContent, "Slide 1 of 2: Hello");
  assert.equal(page.location.hash, "#1.1");
});

test("Enter in the overview goes to the selected slide, and gives its name and its step", () => {
  page.press("o");
  page.press("j");
  page.press("Enter");

  assert.equal(page.announce.textContent, "Slide 2 of 2, step 1 of 2");
  assert.equal(page.location.hash, "#2.1");
});

test("Enter on the slide of the current step closes the overview, and gives the position", () => {
  page.press("o");
  page.announce.textContent = "";
  page.press("Enter");

  assert.equal(page.announce.textContent, "Slide 2 of 2, step 1 of 2");
  assert.equal(page.location.hash, "#2.1");
});
