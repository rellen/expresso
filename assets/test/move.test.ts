import { test } from "node:test";
import assert from "node:assert/strict";
import { distance, names } from "../src/move.ts";

const box = (left: number, top: number, right: number, bottom: number) => ({
  left,
  top,
  right,
  bottom,
});

test("distance goes from the center of one box to the center of the other", () => {
  assert.deepEqual(distance(box(0, 0, 10, 10), box(100, 20, 120, 40), 1), {
    x: 105,
    y: 25,
  });
  assert.deepEqual(distance(box(100, 20, 120, 40), box(0, 0, 10, 10), 1), {
    x: -105,
    y: -25,
  });
});

test("distance divides by the scale of the slide, with two decimals", () => {
  assert.deepEqual(distance(box(0, 0, 10, 10), box(100, 0, 110, 10), 2), {
    x: 50,
    y: 0,
  });
  assert.deepEqual(distance(box(0, 0, 0, 0), box(10, 0, 10, 0), 3), {
    x: 3.33,
    y: 0,
  });
});

test("a box at the same center gives zero, and not minus zero", () => {
  const { x, y } = distance(box(0, 0, 10, 10), box(-5, -5, 15, 15), -1);
  assert.ok(Object.is(x, 0) && Object.is(y, 0));
});

test("names gives the data-part and each class of an element", () => {
  const element = (attributes: Record<string, string>) => ({
    getAttribute: (name: string) => attributes[name] ?? null,
  });
  assert.deepEqual(
    names(element({ "data-part": "redex", class: "math-part  arg" })),
    ["redex", "math-part", "arg"],
  );
  assert.deepEqual(names(element({})), []);
});
