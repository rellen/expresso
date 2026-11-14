import { test, before, mock } from "node:test";
import assert from "node:assert/strict";
import { fakePage } from "./page.ts";
import { nth } from "./nth.ts";

// The present view of a deck with the option `loop`. Slide 1 has two steps,
// slide 2 has one step, and each step has a time of 1 second. `?paused` in
// the address stops the clock at the load.
mock.timers.enable({ apis: ["Date"], now: 0 });
const page = fakePage([2, 1], {
  search: "?paused",
  hash: "#1.1",
  advance: [1000, 1000],
  loop: true,
});

before(async () => {
  await import("../src/main.ts");
});

function pass(milliseconds: number): void {
  mock.timers.tick(milliseconds);
  nth(page.timers, 0)();
}

test("?paused in the address stops the clock at the load", () => {
  assert.equal(page.body.dataset.paused, "true");
  pass(60_000);

  assert.equal(page.location.hash, "#1.1");
});

test("a starts the clock, and the time of the step starts then", () => {
  page.press("a");
  assert.equal(page.body.dataset.paused, undefined);

  pass(999);
  assert.equal(page.location.hash, "#1.1");
  pass(1);
  assert.equal(page.location.hash, "#1.2");
});

test("the step after the last step is the first step", () => {
  pass(1000);
  assert.equal(page.location.hash, "#2.1");

  pass(1000);
  assert.equal(page.location.hash, "#1.1");

  pass(1000);
  assert.equal(page.location.hash, "#1.2");
});

test("the key of the next step also goes from the last step to the first step", () => {
  page.press("End");
  assert.equal(page.location.hash, "#2.1");

  page.press("j");
  assert.equal(page.location.hash, "#1.1");
});

test("the key of the previous step does not go from the first step to the last step", () => {
  page.press("k");

  assert.equal(page.location.hash, "#1.1");
});
