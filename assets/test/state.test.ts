import { test } from "node:test";
import assert from "node:assert/strict";
import { initial, maxStep, next } from "../src/state.ts";

// Three slides. Slide 2 has three steps, and slide 3 has two steps.
const three = { slides: 3, steps: [1, 3, 2] };

test("the initial state is slide 1, step 1", () => {
  assert.deepEqual(initial(), { slide: 1, step: 1 });
});

test("maxStep reads the entry of the slide, and gives 1 without an entry", () => {
  assert.equal(maxStep(2, three), 3);
  assert.equal(maxStep(1, { slides: 1, steps: [] }), 1);
});

test("j moves to the next step", () => {
  assert.deepEqual(next({ slide: 2, step: 1 }, "j", three), {
    slide: 2,
    step: 2,
  });
});

test("j on the last step moves to the first step of the next slide", () => {
  assert.deepEqual(next({ slide: 2, step: 3 }, "j", three), {
    slide: 3,
    step: 1,
  });
  assert.deepEqual(next({ slide: 1, step: 1 }, "j", three), {
    slide: 2,
    step: 1,
  });
});

test("j on the last step of the last slide gives the same state", () => {
  const state = { slide: 3, step: 2 };
  assert.equal(next(state, "j", three), state);
});

test("k moves to the previous step", () => {
  assert.deepEqual(next({ slide: 2, step: 3 }, "k", three), {
    slide: 2,
    step: 2,
  });
});

test("k on the first step moves to the last step of the previous slide", () => {
  assert.deepEqual(next({ slide: 3, step: 1 }, "k", three), {
    slide: 2,
    step: 3,
  });
  assert.deepEqual(next({ slide: 2, step: 1 }, "k", three), {
    slide: 1,
    step: 1,
  });
});

test("k on the first step of the first slide gives the same state", () => {
  const state = { slide: 1, step: 1 };
  assert.equal(next(state, "k", three), state);
});

test("an unknown key gives the same state", () => {
  const state = { slide: 2, step: 2 };
  assert.equal(next(state, "x", three), state);
  assert.equal(next(state, "p", three), state);
});

test("a deck with no slide stays on slide 1, step 1", () => {
  const state = initial();
  const empty = { slides: 0, steps: [] };
  assert.equal(next(state, "j", empty), state);
  assert.equal(next(state, "k", empty), state);
});

test("a slide without an entry in steps has one step", () => {
  const limits = { slides: 2, steps: [] };
  assert.deepEqual(next({ slide: 1, step: 1 }, "j", limits), {
    slide: 2,
    step: 1,
  });
  assert.deepEqual(next({ slide: 2, step: 1 }, "k", limits), {
    slide: 1,
    step: 1,
  });
});
