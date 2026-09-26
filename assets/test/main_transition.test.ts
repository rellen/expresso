import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage } from "./page.ts";

// Four slides. Slide 2 has two steps. The renderer gives the kinds fade,
// slide, none and zoom, and the browser has the View Transitions API.
const page = fakePage([1, 2, 1, 1], {
  transitions: ["fade", "slide", "none", "zoom"],
  viewTransitions: true,
});
const { slides } = page;

before(async () => {
  await import("../src/main.ts");
});

function shown(): number {
  return slides.findIndex((slide) => slide.style.display === "flex") + 1;
}

test("the load of the page runs no transition", () => {
  assert.deepEqual(page.transitions, []);
  assert.equal(shown(), 1);
});

test("a move to the next slide runs the transition of that slide", () => {
  page.press("j");

  assert.deepEqual(page.transitions, ["slide forward"]);
  assert.equal(shown(), 2);
});

test("a change of the step runs no transition", () => {
  page.press("j");

  assert.deepEqual(page.transitions, ["slide forward"]);
  assert.equal(slides[1].dataset.step, "2");
});

test("the kind none shows the slide with no transition", () => {
  page.press("j");

  assert.deepEqual(page.transitions, ["slide forward"]);
  assert.equal(shown(), 3);
});

test("a move back plays the kind of the slide that it leaves", () => {
  page.press("j");
  page.press("k");

  assert.deepEqual(page.transitions, [
    "slide forward",
    "zoom forward",
    "zoom back",
  ]);
  assert.equal(shown(), 3);
});

test("a click and an address run the transition too", () => {
  page.transitions.length = 0;
  // From slide 3 to slide 2, and from slide 2 to slide 1. The border of
  // slides 2 and 3 has the kind none.
  page.click(0);
  page.click(0);
  page.click(0);
  page.navigate("#4.1");

  assert.deepEqual(page.transitions, ["slide back", "zoom forward"]);
  assert.equal(shown(), 4);
});

test("a reader who asks for reduced motion gets no transition", () => {
  page.transitions.length = 0;
  page.reduced = true;
  page.press("Home");

  assert.deepEqual(page.transitions, []);
  assert.equal(shown(), 1);
});
