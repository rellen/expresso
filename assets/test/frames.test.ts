import { test } from "node:test";
import assert from "node:assert/strict";
import { hold, times } from "../gifs/frames.ts";

test("times gives one frame each 40 ms, and a last frame at the end", () => {
  assert.deepEqual(times(200), [40, 80, 120, 160, 200]);
  assert.deepEqual(times(300), [40, 80, 120, 160, 200, 240, 280, 300]);
});

test("times gives no frame for an animation of no time", () => {
  assert.deepEqual(times(0), []);
  assert.deepEqual(times(-5), []);
  assert.deepEqual(times(Number.NaN), []);
});

test("times takes a number of frames per second", () => {
  assert.deepEqual(times(100, 10), [100]);
  assert.deepEqual(times(250, 10), [100, 200, 250]);
});

test("the last key of an example holds its frame longer", () => {
  assert.ok(hold(true) > hold(false));
});
