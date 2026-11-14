import { test } from "node:test";
import assert from "node:assert/strict";
import { due, left, runs, start, text, update, used } from "../src/advance.ts";
import { deckOf } from "./decks.ts";
import { load } from "./fixtures.ts";

const state = load("1,2").program.state;

// Three slides of 1, 2 and 1 steps. Slide 1 has no time, each step of slide
// 2 has 5 seconds, and slide 3 has 20 seconds.
const deck = deckOf([1, 2, 1], { advance: [null, 5000, 20_000] });
const loop = deckOf([1, 2, 1], { advance: [null, 5000, 20_000], loop: true });

test("the clock runs in the present view and in the speaker view", () => {
  assert.equal(runs({ ...state, view: "present" }), true);
  assert.equal(runs({ ...state, view: "speaker" }), true);
  assert.equal(runs({ ...state, view: "handout" }), false);
});

test("the clock does not run while it is stopped, or on a black screen", () => {
  assert.equal(runs({ ...state, paused: true }), false);
  assert.equal(runs({ ...state, blank: true }), false);
  assert.equal(runs({ ...state, blank: true, white: true }), false);
});

test("the overview, the menu and the list of keys do not stop the clock", () => {
  assert.equal(runs({ ...state, overview: true }), true);
  assert.equal(runs({ ...state, menu: true }), true);
  assert.equal(runs({ ...state, help: true }), true);
});

test("start gives a clock with no time used", () => {
  assert.deepEqual(start(2, true, 1000), { index: 2, spent: 0, since: 1000 });
  assert.deepEqual(start(2, false, 1000), { index: 2, spent: 0, since: null });
});

test("used counts the time from the start of a clock that runs", () => {
  assert.equal(used(start(1, true, 1000), 1000), 0);
  assert.equal(used(start(1, true, 1000), 4000), 3000);
  assert.equal(used(start(1, false, 1000), 4000), 0);
});

test("used does not count a time before the start", () => {
  assert.equal(used(start(1, true, 5000), 4000), 0);
});

test("update starts the time of a different step from zero", () => {
  const clock = start(1, true, 1000);

  assert.deepEqual(update(clock, 2, true, 4000), {
    index: 2,
    spent: 0,
    since: 4000,
  });
  assert.deepEqual(update(clock, 2, false, 4000), {
    index: 2,
    spent: 0,
    since: null,
  });
});

test("update keeps the time that the step used when the clock stops", () => {
  const stopped = update(start(1, true, 1000), 1, false, 4000);

  assert.deepEqual(stopped, { index: 1, spent: 3000, since: null });
  assert.equal(used(stopped, 60_000), 3000);
});

test("update continues the time of the step when the clock starts again", () => {
  const stopped = update(start(1, true, 1000), 1, false, 4000);
  const started = update(stopped, 1, true, 10_000);

  assert.deepEqual(started, { index: 1, spent: 3000, since: 10_000 });
  assert.equal(used(started, 11_000), 4000);
});

test("update returns the same clock for no change", () => {
  const running = start(1, true, 1000);
  const stopped = start(1, false, 1000);

  assert.equal(update(running, 1, true, 4000), running);
  assert.equal(update(stopped, 1, false, 4000), stopped);
});

test("left returns the time of the step minus the time that it used", () => {
  const clock = start(1, true, 1000);

  assert.equal(left(clock, deck.steps[1], 1000), 5000);
  assert.equal(left(clock, deck.steps[1], 3500), 2500);
  assert.equal(left(clock, deck.steps[1], 6000), 0);
  assert.equal(left(clock, deck.steps[1], 60_000), 0);
});

test("left returns null for a step with no time, and for no step", () => {
  assert.equal(left(start(0, true, 0), deck.steps[0], 1000), null);
  assert.equal(left(start(9, true, 0), undefined, 1000), null);
});

test("left returns null for the last step of a deck with no loop", () => {
  assert.equal(left(start(3, true, 0), deck.steps[3], 1000), null);
  assert.equal(left(start(3, true, 0), loop.steps[3], 1000), 19_000);
});

test("left returns null for a deck with one step and the option loop", () => {
  const one = deckOf([1], { advance: [1000], loop: true });

  assert.equal(one.steps[0]?.next, 0);
  assert.equal(left(start(0, true, 0), one.steps[0], 5000), null);
});

test("due is true when the time of the step ended and the clock runs", () => {
  const clock = start(1, true, 1000);

  assert.equal(due(clock, deck.steps[1], 5999), false);
  assert.equal(due(clock, deck.steps[1], 6000), true);
  assert.equal(due(clock, deck.steps[1], 9000), true);
});

test("due is false while the clock does not run, and for a step that waits for a key", () => {
  const stopped = update(start(1, true, 1000), 1, false, 9000);

  assert.equal(left(stopped, deck.steps[1], 9000), 0);
  assert.equal(due(stopped, deck.steps[1], 9000), false);
  assert.equal(due(start(0, true, 0), deck.steps[0], 99_000), false);
  assert.equal(due(start(3, true, 0), deck.steps[3], 99_000), false);
});

test("text gives the time left, up to the next full second", () => {
  assert.equal(text(5000, true), "Next step in 0:05");
  assert.equal(text(4999, true), "Next step in 0:05");
  assert.equal(text(4001, true), "Next step in 0:05");
  assert.equal(text(4000, true), "Next step in 0:04");
  assert.equal(text(1, true), "Next step in 0:01");
  assert.equal(text(0, true), "Next step in 0:00");
  assert.equal(text(75_000, true), "Next step in 1:15");
});

test("text tells when the clock does not run", () => {
  assert.equal(text(4200, false), "Clock stopped, 0:05 to the next step");
});

test("text is empty for a step that waits for a key", () => {
  assert.equal(text(null, true), "");
  assert.equal(text(null, false), "");
});
