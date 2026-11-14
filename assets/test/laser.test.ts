import { test } from "node:test";
import assert from "node:assert/strict";
import {
  isPointer,
  placeIn,
  placeOf,
  pointer,
  pointing,
  pointOf,
} from "../src/laser.ts";
import { deckOf, at } from "./decks.ts";

const box = { left: 100, top: 50, width: 600, height: 300 };

test("placeIn returns the place of a point as a part of the box", () => {
  assert.deepEqual(placeIn(100, 50, box), { x: 0, y: 0 });
  assert.deepEqual(placeIn(400, 200, box), { x: 0.5, y: 0.5 });
  assert.deepEqual(placeIn(700, 350, box), { x: 1, y: 1 });
});

test("placeIn returns null for a point outside the box, and for no box", () => {
  assert.equal(placeIn(99, 200, box), null);
  assert.equal(placeIn(701, 200, box), null);
  assert.equal(placeIn(400, 49, box), null);
  assert.equal(placeIn(400, 351, box), null);
  assert.equal(placeIn(400, 200, null), null);
  assert.equal(placeIn(0, 0, { left: 0, top: 0, width: 0, height: 0 }), null);
});

test("pointOf returns the point of a place in a box of a different size", () => {
  const place = placeIn(250, 125, box);
  assert.ok(place);

  assert.deepEqual(
    pointOf(place, { left: 0, top: 0, width: 1920, height: 1080 }),
    { left: 480, top: 270 },
  );
  assert.deepEqual(pointOf(place, box), { left: 250, top: 125 });
});

test("pointer makes a message with the place, or with null for no dot", () => {
  assert.deepEqual(pointer({ x: 0.25, y: 0.5 }), {
    expresso: "pointer",
    x: 0.25,
    y: 0.5,
  });
  assert.deepEqual(pointer(null), { expresso: "pointer", x: null, y: null });
});

test("isPointer takes a message of the pointer, also with other keys", () => {
  assert.ok(isPointer(pointer({ x: 0, y: 1 })));
  assert.ok(isPointer(pointer(null)));
  assert.ok(
    isPointer({ ...pointer({ x: 0.5, y: 0.5 }), from: "an extension" }),
  );
});

test("isPointer refuses a place outside the slide and each other value", () => {
  assert.equal(isPointer({ expresso: "pointer", x: 1.5, y: 0.5 }), false);
  assert.equal(isPointer({ expresso: "pointer", x: 0.5, y: -0.1 }), false);
  assert.equal(isPointer({ expresso: "pointer", x: "0.5", y: 0.5 }), false);
  assert.equal(isPointer({ expresso: "pointer", x: 0.5 }), false);
  assert.equal(isPointer({ expresso: "position", x: 0.5, y: 0.5 }), false);
  assert.equal(isPointer(null), false);
  assert.equal(isPointer("pointer"), false);
});

test("placeOf returns the place of a message, or null for no dot", () => {
  assert.deepEqual(placeOf(pointer({ x: 0.25, y: 0.5 })), { x: 0.25, y: 0.5 });
  assert.equal(placeOf(pointer(null)), null);
  assert.equal(placeOf({ expresso: "pointer", x: 0.5, y: null }), null);
});

test("pointing is true only while the pointer is on and the view shows a slide", () => {
  const deck = deckOf([2]);
  const on = { ...at(deck, 1, 1), laser: true };

  assert.equal(pointing(at(deck, 1, 1)), false);
  assert.equal(pointing(on), true);
  assert.equal(pointing({ ...on, view: "speaker" }), true);
  assert.equal(pointing({ ...on, view: "handout" }), false);
  assert.equal(pointing({ ...on, blank: true }), false);
  assert.equal(pointing({ ...on, overview: true }), false);
  assert.equal(pointing({ ...on, menu: true }), false);
  assert.equal(pointing({ ...on, help: true }), false);
});
