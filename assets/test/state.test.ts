// The tests of the code that stays in `state.ts`: the messages between the
// windows and the sources of the click events and the swipe events. The tests
// of the keys and the moves run on the program: `interpreter.test.ts` runs the
// fixtures, and `test/expresso/presenter/` holds the ExUnit tests.

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  accepts,
  current,
  isMessage,
  message,
  side,
  stamp,
  swipe,
  synced,
} from "../src/state.ts";
import { at, deckOf } from "./decks.ts";
import { load, raw } from "./fixtures.ts";
import { position } from "./messages.ts";

// The program of the presenter. Each deck of the fixtures has the same `sync`.
const { program } = load(Object.keys(raw.decks)[0] ?? "");

// Three slides. Slide 2 has three steps, and slide 3 has two steps.
const three = deckOf([1, 3, 2]);

test("current returns the entry of the state, and undefined for a deck with no slide", () => {
  assert.deepEqual(current(at(three, 2, 3), three), three.steps[3]);
  assert.equal(current(at(three, 1, 1), deckOf([])), undefined);
});

test("message holds the slide, the step, the fields of sync, the variant and the time", () => {
  assert.deepEqual(
    message(
      program,
      { ...at(three, 2, 3), blank: true, digits: "4" },
      three,
      17,
      "dark",
    ),
    position({ slide: 2, step: 3, blank: true, scheme: "dark", time: 17 }),
  );
});

test("synced is true for a change of the step or of a field of sync only", () => {
  const state = at(three, 2, 1);
  assert.equal(synced(program, state, at(three, 2, 2)), true);
  assert.equal(synced(program, state, { ...state, blank: true }), true);
  assert.equal(synced(program, state, { ...state, undim: true }), true);
  assert.equal(synced(program, state, { ...state, overview: true }), false);
  assert.equal(synced(program, state, { ...state, digits: "2" }), false);
});

test("isMessage accepts only a message of the presenter", () => {
  const good = message(program, at(three, 1, 1), three, 1, null);
  assert.equal(isMessage(good), true);
  const { fields, time, scheme, ...rest } = good;
  const others = [
    null,
    "position",
    { ...good, expresso: "other" },
    { ...good, slide: "1" },
    { ...good, slide: 1.5 },
    { ...rest, time, scheme },
    { ...rest, fields, scheme },
    { ...good, time: "1" },
    { ...good, time: NaN },
    { ...rest, fields, time },
    { ...good, scheme: "sepia" },
    { ...good, fields: { blank: 1 } },
    { ...good, fields: { color: true } },
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
