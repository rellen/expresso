import { test } from "node:test";
import assert from "node:assert/strict";
import { broken, first, label, past, sentence } from "../src/layout.ts";
import type { Problem } from "../src/layout.ts";

const window = { left: 0, top: 0, right: 1920, bottom: 1080 };

test("past returns null for a box inside the window, and for one pixel of rounding", () => {
  assert.equal(
    past({ left: 10, top: 10, right: 1900, bottom: 1000 }, window),
    null,
  );
  assert.equal(
    past({ left: -1, top: 0, right: 1921, bottom: 1080.5 }, window),
    null,
  );
});

test("past returns the edge with the largest distance, in whole pixels", () => {
  assert.deepEqual(
    past({ left: 100, top: 50, right: 2040.4, bottom: 900 }, window),
    {
      edge: "right",
      amount: 120,
    },
  );
  assert.deepEqual(
    past({ left: -30, top: 50, right: 1990, bottom: 900 }, window),
    {
      edge: "right",
      amount: 70,
    },
  );
  assert.deepEqual(
    past({ left: 0, top: -12, right: 100, bottom: 1300 }, window),
    {
      edge: "bottom",
      amount: 220,
    },
  );
});

test("broken counts the lines that are more than one and a half line heights", () => {
  assert.equal(broken([20, 20, 40, 20, 60], 20), 2);
  assert.equal(broken([20, 29], 20), 0);
  assert.equal(broken([], 20), 0);
});

test("broken counts no line when the line height is unknown", () => {
  assert.equal(broken([40, 60], 0), 0);
  assert.equal(broken([40, 60], Number.NaN), 0);
});

test("label names the kind and the start of the text", () => {
  assert.equal(label("math", "  s =\n  o + x "), "math “s = o + x”");
  assert.equal(label("diagram", ""), "diagram");
  assert.equal(label("code", "x".repeat(50)), `code “${"x".repeat(40)}…”`);
});

const outside: Problem = {
  slide: 6,
  step: 3,
  kind: "outside",
  edge: "right",
  amount: 120,
  element: "math “s”",
};

const wrap: Problem = {
  slide: 13,
  step: 1,
  kind: "wrap",
  edge: null,
  amount: 2,
  element: "code “m1”",
};

test("sentence tells the slide, the step and the problem", () => {
  assert.equal(
    sentence(outside),
    "Slide 6, step 3: the math “s” goes 120 px past the right edge",
  );
  assert.equal(
    sentence(wrap),
    "Slide 13, step 1: 2 lines break in the code “m1”",
  );
  assert.equal(
    sentence({ ...wrap, amount: 1 }),
    "Slide 13, step 1: 1 line breaks in the code “m1”",
  );
});

test("first keeps the first step of each problem", () => {
  const later = { ...outside, step: 4, amount: 130 };
  const other = { ...outside, edge: "bottom" as const };
  assert.deepEqual(first([outside, later, wrap, other]), [
    outside,
    wrap,
    other,
  ]);
});
