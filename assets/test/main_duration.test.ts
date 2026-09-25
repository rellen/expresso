import { test, before, mock } from "node:test";
import assert from "node:assert/strict";
import { fakePage, fakeWindow } from "./page.ts";

// The speaker view of four slides of one step each. The deck gives a talk of
// 20 minutes, and the address gives 10 minutes, so the talk has 10 minutes.
// Each slide is then 2.5 minutes of the talk.
const page = fakePage([1, 1, 1, 1], {
  search: "?speaker&duration=10",
  hash: "#1.1",
  opener: fakeWindow(),
  duration: "20",
});

// The clock of the timer starts at 0, and each test moves it by hand.
mock.timers.enable({ apis: ["Date"], now: 0 });

before(async () => {
  await import("../src/main.ts");
});

function left(): { text?: string; pace?: string } {
  const element = page.element("speaker-left");
  return { text: element?.textContent, pace: element?.dataset.pace };
}

function tick(milliseconds: number): void {
  mock.timers.tick(milliseconds);
  page.timers[0]();
}

test("the speaker view shows the whole time of the address before the start", () => {
  assert.deepEqual(left(), { text: "10:00 left", pace: "on" });
});

test("the time left goes down from the first change of the step", () => {
  page.press("j");
  tick(60_000);

  assert.deepEqual(left(), { text: "9:00 left", pace: "on" });
});

test("the pace is behind after more than one minute behind the steps", () => {
  // Slide 2 starts after 2.5 minutes of the talk. At 3:31, the talk is 61
  // seconds behind.
  tick(151_000);

  assert.deepEqual(left(), { text: "6:29 left", pace: "behind" });
});

test("a move to the next slide gives the pace again", () => {
  page.press("j");
  tick(0);

  assert.equal(left().pace, "on");
});

test("the pace is over after the end of the time", () => {
  tick(7 * 60_000);

  assert.deepEqual(left(), { text: "+0:31 over", pace: "over" });
});

test("r sets the time left back to the whole time", () => {
  page.press("r");

  assert.deepEqual(left(), { text: "10:00 left", pace: "on" });
});
