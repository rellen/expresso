import { test } from "node:test";
import assert from "node:assert/strict";
import { initial, maxStep, next } from "../src/state.ts";
import type { State, View } from "../src/state.ts";

// Three slides. Slide 2 has three steps, and slide 3 has two steps.
const three = { slides: 3, steps: [1, 3, 2] };

// A state of the present view.
function at(slide: number, step: number, view: View = "present"): State {
  return { slide, step, view };
}

test("the initial state is slide 1, step 1, in the present view", () => {
  assert.deepEqual(initial(), { slide: 1, step: 1, view: "present" });
});

test("maxStep reads the entry of the slide, and gives 1 without an entry", () => {
  assert.equal(maxStep(2, three), 3);
  assert.equal(maxStep(1, { slides: 1, steps: [] }), 1);
});

test("j moves to the next step", () => {
  assert.deepEqual(next(at(2, 1), "j", three), at(2, 2));
});

test("j on the last step moves to the first step of the next slide", () => {
  assert.deepEqual(next(at(2, 3), "j", three), at(3, 1));
  assert.deepEqual(next(at(1, 1), "j", three), at(2, 1));
});

test("j on the last step of the last slide gives the same state", () => {
  const state = at(3, 2);
  assert.equal(next(state, "j", three), state);
});

test("k moves to the previous step", () => {
  assert.deepEqual(next(at(2, 3), "k", three), at(2, 2));
});

test("k on the first step moves to the last step of the previous slide", () => {
  assert.deepEqual(next(at(3, 1), "k", three), at(2, 3));
  assert.deepEqual(next(at(2, 1), "k", three), at(1, 1));
});

test("k on the first step of the first slide gives the same state", () => {
  const state = at(1, 1);
  assert.equal(next(state, "k", three), state);
});

test("p changes to the handout view, and p again changes back", () => {
  const handout = next(at(2, 2), "p", three);
  assert.deepEqual(handout, at(2, 2, "handout"));
  assert.deepEqual(next(handout, "p", three), at(2, 2));
});

test("j and k keep the view", () => {
  assert.deepEqual(next(at(2, 1, "handout"), "j", three), at(2, 2, "handout"));
  assert.deepEqual(next(at(2, 2, "handout"), "k", three), at(2, 1, "handout"));
});

test("an unknown key gives the same state", () => {
  const state = at(2, 2);
  assert.equal(next(state, "x", three), state);
});

test("a deck with no slide stays on slide 1, step 1", () => {
  const state = initial();
  const empty = { slides: 0, steps: [] };
  assert.equal(next(state, "j", empty), state);
  assert.equal(next(state, "k", empty), state);
});

test("a slide without an entry in steps has one step", () => {
  const limits = { slides: 2, steps: [] };
  assert.deepEqual(next(at(1, 1), "j", limits), at(2, 1));
  assert.deepEqual(next(at(2, 1), "k", limits), at(1, 1));
});
