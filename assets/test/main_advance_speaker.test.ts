import { test, before, mock } from "node:test";
import assert from "node:assert/strict";
import { fakePage, fakeWindow } from "./page.ts";
import { position } from "./messages.ts";
import { nth } from "./nth.ts";

// The speaker view of a deck with two slides. Slide 1 has two steps of 5
// seconds each, and slide 2 has one step with no time. The present view
// opened this window. The clock of the test starts at 0.
mock.timers.enable({ apis: ["Date"], now: 0 });
const opener = fakeWindow();
const page = fakePage([2, 1], {
  search: "?speaker",
  hash: "#1.1",
  opener,
  advance: [5000, null],
});

before(async () => {
  await import("../src/main.ts");
});

// Move the clock, and run the function of the timer of the speaker view.
function pass(milliseconds: number): void {
  mock.timers.tick(milliseconds);
  nth(page.timers, 0)();
}

function shown(): string | undefined {
  return page.element("speaker-advance")?.textContent;
}

test("the speaker view shows the time left of the step", () => {
  pass(0);
  assert.equal(shown(), "Next step in 0:05");

  pass(1500);
  assert.equal(shown(), "Next step in 0:04");
});

test("the speaker view does not go to the next step itself", () => {
  assert.equal(page.timers.length, 1);
  pass(60_000);

  assert.equal(page.location.hash, "#1.1");
  assert.equal(shown(), "Next step in 0:00");
});

test("the move of the present view starts the time of the new step", () => {
  // The clock of the test can give the same time to two messages, so the
  // time of this message is after each time of this window.
  page.receive(position({ step: 2, time: Date.now() + 60_000 }), opener);
  pass(0);

  assert.equal(page.location.hash, "#1.2");
  assert.equal(shown(), "Next step in 0:05");
});

test("a stops the clock in the two windows, and the text tells it", () => {
  pass(2000);
  page.press("a");
  pass(60_000);

  assert.equal(page.body.dataset.paused, "true");
  assert.equal(shown(), "Clock stopped, 0:03 to the next step");
  const message = opener.received[opener.received.length - 1] as {
    fields: { paused: boolean };
  };
  assert.equal(message.fields.paused, true);
});

test("a message of the present view starts the clock again", () => {
  page.receive(
    position({ step: 2, paused: false, time: Date.now() + 60_000 }),
    opener,
  );
  pass(1000);

  assert.equal(page.body.dataset.paused, undefined);
  assert.equal(shown(), "Next step in 0:02");
});

test("a step with no time shows no text", () => {
  page.press("j");
  pass(1000);

  assert.equal(page.location.hash, "#2.1");
  assert.equal(shown(), "");
});

test("the list of keys shows the key of the clock", () => {
  page.press("?");
  const names = page.keys().map((each) => each.names);

  assert.ok(names.includes("a"), "the list has no key a");
});
