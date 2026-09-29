import { test } from "node:test";
import assert from "node:assert/strict";
import {
  clock,
  left,
  pace,
  position,
  SLACK,
  talkLength,
} from "../src/speaker.ts";
import { deckOf } from "./decks.ts";
import { nth } from "./nth.ts";

// Three slides. Slide 2 has three steps, and slide 3 has two steps.
const three = deckOf([1, 3, 2]);

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

test("position gives the position of the entry", () => {
  assert.equal(position(nth(three.steps, 0), false), "Slide 1 of 3");
  assert.equal(
    position(nth(three.steps, 2), false),
    "Slide 2 of 3, step 2 of 3",
  );
});

test("position tells about a black screen", () => {
  assert.equal(
    position(nth(three.steps, 0), true),
    "Slide 1 of 3, black screen",
  );
});

test("position gives only the black screen for a deck with no slide", () => {
  assert.equal(position(undefined, false), "");
  assert.equal(position(undefined, true), "black screen");
});

test("talkLength gives the length of the list of the steps", () => {
  assert.equal(talkLength(20 * 60_000, null), 20 * 60_000);
  assert.equal(talkLength(null, null), null);
});

test("talkLength takes the minutes of the address parameter first", () => {
  assert.equal(talkLength(20 * 60_000, "15"), 15 * 60_000);
  assert.equal(talkLength(null, "0.5"), 30_000);
});

test("talkLength ignores a parameter that is not a positive number", () => {
  for (const value of ["", "abc", "0", "-5", "Infinity", "1e305"]) {
    assert.equal(talkLength(null, value), null, value);
    assert.equal(talkLength(20 * 60_000, value), 20 * 60_000, value);
  }
});

test("left gives the time left, up to the next full second", () => {
  assert.equal(left(0, 600_000), "10:00 left");
  assert.equal(left(210_500, 600_000), "6:30 left");
  assert.equal(left(600_000, 600_000), "0:00 left");
});

test("left gives the time after the end of the talk", () => {
  assert.equal(left(600_001, 600_000), "+0:00 over");
  assert.equal(left(690_000, 600_000), "+1:30 over");
});

test("pace is on until more than one minute behind the part of the deck", () => {
  // Half of the deck is done after half of the time, and after one more minute.
  assert.equal(pace(300_000, 600_000, 0.5), "on");
  assert.equal(pace(300_000 + SLACK, 600_000, 0.5), "on");
  assert.equal(pace(300_000 + SLACK + 1, 600_000, 0.5), "behind");
  // A speaker who is ahead is on pace.
  assert.equal(pace(60_000, 600_000, 0.9), "on");
});

test("pace is over after the end of the time", () => {
  assert.equal(pace(600_000, 600_000, 0.2), "behind");
  assert.equal(pace(600_001, 600_000, 1), "over");
});
