// The tests of the code that stays in `state.ts`: the messages between the
// windows and the sources of the click events and the swipe events. The tests
// of the keys and the moves run on the program: `interpreter.test.ts` runs the
// fixtures, and `test/expresso/presenter/` holds the ExUnit tests.

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  accepts,
  columns,
  current,
  isMessage,
  message,
  side,
  stamp,
  swipe,
} from "../src/state.ts";
import { at, deckOf } from "./decks.ts";

// Three slides. Slide 2 has three steps, and slide 3 has two steps.
const three = deckOf([1, 3, 2]);

test("current returns the entry of the state, and undefined for a deck with no slide", () => {
  assert.deepEqual(current(at(three, 2, 3), three), three.steps[3]);
  assert.equal(current(at(three, 1, 1), deckOf([])), undefined);
});

test("message holds the slide, the step, the black screen and the time", () => {
  assert.deepEqual(
    message({ ...at(three, 2, 3), blank: true, digits: "4" }, three, 17),
    { expresso: "position", slide: 2, step: 3, blank: true, time: 17 },
  );
});

test("isMessage accepts only a message of the presenter", () => {
  assert.equal(isMessage(message(at(three, 1, 1), three, 1)), true);
  const others = [
    null,
    "position",
    { expresso: "other", slide: 1, step: 1, blank: false, time: 1 },
    { expresso: "position", slide: "1", step: 1, blank: false, time: 1 },
    { expresso: "position", slide: 1.5, step: 1, blank: false, time: 1 },
    { expresso: "position", slide: 1, step: 1, time: 1 },
    { expresso: "position", slide: 1, step: 1, blank: false },
    { expresso: "position", slide: 1, step: 1, blank: false, time: "1" },
    { expresso: "position", slide: 1, step: 1, blank: false, time: NaN },
  ];
  for (const data of others) {
    assert.equal(isMessage(data), false, JSON.stringify(data));
  }
});

test("stamp returns the clock, or one more than the last time", () => {
  assert.equal(stamp(0, 500), 500);
  assert.equal(stamp(500, 500), 501);
  assert.equal(stamp(900, 500), 901);
});

test("accepts takes a newer message, and ignores an older one", () => {
  for (const speaker of [true, false]) {
    assert.equal(accepts(10, 11, speaker), true);
    assert.equal(accepts(10, 9, speaker), false);
  }
});

test("at the same time, the speaker view takes the message and the present view keeps its state", () => {
  assert.equal(accepts(10, 10, true), true);
  assert.equal(accepts(10, 10, false), false);
});

test("side returns the left third, and the right for the rest", () => {
  assert.equal(side(0, 1200), "left_third");
  assert.equal(side(399, 1200), "left_third");
  assert.equal(side(400, 1200), "right");
  assert.equal(side(1199, 1200), "right");
});

test("swipe returns the direction of a swipe, and nothing for a short or vertical movement", () => {
  assert.equal(swipe(-50, 0), "left");
  assert.equal(swipe(80, -30), "right");
  assert.equal(swipe(-49, 0), undefined);
  assert.equal(swipe(60, 60), undefined);
  assert.equal(swipe(0, -200), undefined);
});

test("columns returns a grid with as many rows as columns or fewer", () => {
  assert.equal(columns(0), 1);
  assert.equal(columns(1), 1);
  assert.equal(columns(4), 2);
  assert.equal(columns(5), 3);
  assert.equal(columns(13), 4);
  for (let slides = 1; slides <= 100; slides++) {
    const width = columns(slides);
    assert.ok(Math.ceil(slides / width) <= width, String(slides));
  }
});
