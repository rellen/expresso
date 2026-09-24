import { test } from "node:test";
import assert from "node:assert/strict";
import { clock, describe } from "../src/speaker.ts";
import type { State } from "../src/state.ts";

const three = { slides: 3, steps: [1, 3, 2] };

function at(slide: number, step: number, blank = false): State {
  return { slide, step, view: "speaker", blank, digits: "" };
}

test("clock gives minutes and seconds", () => {
  assert.equal(clock(0), "0:00");
  assert.equal(clock(999), "0:00");
  assert.equal(clock(61_000), "1:01");
  assert.equal(clock(59 * 60_000 + 59_999), "59:59");
});

test("clock gives hours from one hour", () => {
  assert.equal(clock(3_600_000), "1:00:00");
  assert.equal(clock(3_600_000 + 5 * 60_000 + 7_000), "1:05:07");
});

test("clock gives 0:00 for a time less than zero", () => {
  assert.equal(clock(-5_000), "0:00");
});

test("describe gives the slide, and the step of a slide with more than one step", () => {
  assert.equal(describe(at(1, 1), three), "Slide 1 of 3");
  assert.equal(describe(at(2, 2), three), "Slide 2 of 3, step 2 of 3");
});

test("describe tells about a black screen", () => {
  assert.equal(describe(at(1, 1, true), three), "Slide 1 of 3, black screen");
});
