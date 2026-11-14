import { test, before, mock } from "node:test";
import assert from "node:assert/strict";
import { fakePage, last } from "./page.ts";
import { nth } from "./nth.ts";

// The present view of a deck with two slides. Slide 1 has two steps of 5
// seconds each, and slide 2 has one step of 20 seconds. The deck has no
// option `loop`. The clock of the test starts at 0, and each test moves it
// by hand. The tests run in sequence on the same page.
mock.timers.enable({ apis: ["Date"], now: 0 });
const page = fakePage([2, 1], { hash: "#1.1", advance: [5000, 20_000] });

before(async () => {
  await import("../src/main.ts");
});

// Move the clock, and run the function that the present view gave to
// `setInterval`.
function pass(milliseconds: number): void {
  mock.timers.tick(milliseconds);
  nth(page.timers, 0)();
}

test("the present view of a deck with a time looks at the clock", () => {
  assert.equal(page.timers.length, 1);
});

test("a step stays until its time ends", () => {
  pass(4999);

  assert.equal(page.location.hash, "#1.1");
});

test("the present view goes to the next step when the time of the step ends", () => {
  pass(1);

  assert.equal(page.location.hash, "#1.2");
});

test("the new step starts its time from zero", () => {
  pass(4999);
  assert.equal(page.location.hash, "#1.2");

  pass(1);
  assert.equal(page.location.hash, "#2.1");
});

test("the last step of a deck with no loop waits for a key", () => {
  pass(60_000);

  assert.equal(page.location.hash, "#2.1");
});

test("a key moves, and the new step starts its time from zero", () => {
  page.press("Home");
  assert.equal(page.location.hash, "#1.1");
  pass(3000);
  page.press("j");
  assert.equal(page.location.hash, "#1.2");

  // The 3 seconds of step 1 do not count for step 2.
  pass(4999);
  assert.equal(page.location.hash, "#1.2");
  page.press("k");
  assert.equal(page.location.hash, "#1.1");
});

test("a stops the clock, and the step then waits", () => {
  pass(2000);
  const stopped = page.press("a");

  assert.equal(stopped, true);
  assert.equal(page.body.dataset.paused, "true");
  pass(60_000);
  assert.equal(page.location.hash, "#1.1");
});

test("a second a starts the clock, and the step continues its time", () => {
  page.press("a");

  assert.equal(page.body.dataset.paused, undefined);
  // The step used 2 seconds before the stop.
  pass(2999);
  assert.equal(page.location.hash, "#1.1");
  pass(1);
  assert.equal(page.location.hash, "#1.2");
});

test("a key moves while the clock is stopped, and the new step waits", () => {
  page.press("a");
  page.press("k");
  assert.equal(page.location.hash, "#1.1");
  pass(60_000);
  assert.equal(page.location.hash, "#1.1");

  page.press("a");
  pass(5000);
  assert.equal(page.location.hash, "#1.2");
});

test("a black screen stops the clock, and the step continues after it", () => {
  pass(1000);
  page.press("b");
  pass(60_000);
  assert.equal(page.location.hash, "#1.2");

  page.press("b");
  assert.equal(page.body.dataset.blank, undefined);
  pass(3999);
  assert.equal(page.location.hash, "#1.2");
  pass(1);
  assert.equal(page.location.hash, "#2.1");
});

test("the overview does not stop the clock", () => {
  page.press("Home");
  page.press("o");
  pass(5000);

  assert.equal(page.location.hash, "#1.2");
  assert.equal(page.body.dataset.overview, "true");
  page.press("Escape");
});

test("the move of the clock turns the laser pointer off, as a key does", () => {
  page.press("Home");
  page.press("l");
  assert.equal(page.body.dataset.laser, "true");

  pass(5000);

  assert.equal(page.location.hash, "#1.2");
  assert.equal(page.body.dataset.laser, undefined);
});

test("the move of the clock goes to the speaker view", () => {
  page.press("Home");
  page.press("s");
  const speaker = nth(page.opened, 0).window;
  page.receive({ expresso: "request" }, speaker);

  pass(5000);

  const message = last(speaker) as { slide: number; step: number };
  assert.deepEqual([message.slide, message.step], [1, 2]);
});

test("the handout view stops the clock", () => {
  page.press("Home");
  page.press("p");
  pass(60_000);
  assert.equal(page.location.hash, "#1.1");

  page.press("p");
  pass(5000);
  assert.equal(page.location.hash, "#1.2");
});
