import { test } from "node:test";
import assert from "node:assert/strict";
import { initial, next } from "../src/state.ts";

const three = { slides: 3 };

test("the initial state is slide 1", () => {
  assert.deepEqual(initial(), { slide: 1 });
});

test("j moves to the next slide", () => {
  assert.deepEqual(next({ slide: 1 }, "j", three), { slide: 2 });
});

test("j on the last slide gives the same state", () => {
  const state = { slide: 3 };
  assert.equal(next(state, "j", three), state);
});

test("k moves to the previous slide", () => {
  assert.deepEqual(next({ slide: 3 }, "k", three), { slide: 2 });
});

test("k on the first slide gives the same state", () => {
  const state = { slide: 1 };
  assert.equal(next(state, "k", three), state);
});

test("an unknown key gives the same state", () => {
  const state = { slide: 2 };
  assert.equal(next(state, "x", three), state);
  assert.equal(next(state, "p", three), state);
});

test("a deck with no slide stays on slide 1", () => {
  const state = initial();
  assert.equal(next(state, "j", { slides: 0 }), state);
  assert.equal(next(state, "k", { slides: 0 }), state);
});
