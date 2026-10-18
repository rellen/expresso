import { test, before, mock } from "node:test";
import assert from "node:assert/strict";
import { fakePage, fakeWindow } from "./page.ts";
import { nth } from "./nth.ts";
import { position } from "./messages.ts";

// A speaker view that opens at slide 3 of a deck with three slides of one
// step each. The tests run in sequence on the same page.
const opener = fakeWindow();
const page = fakePage([1, 1, 1], {
  search: "?speaker=&scheme=dark",
  hash: "#3.1",
  opener,
  variants: true,
});

mock.timers.enable({ apis: ["Date"], now: 0 });

before(async () => {
  await import("../src/main.ts");
});

test("at its load, the speaker view only asks the present view for its state", () => {
  assert.equal(page.location.hash, "#3.1");
  assert.deepEqual(opener.received, [{ expresso: "request" }]);
});

test("the timer does not start at the step of the address", () => {
  mock.timers.tick(5_000);
  nth(page.timers, 0)();

  assert.equal(page.element("speaker-timer")?.textContent, "0:00");
});

test("the answer of the present view gives its step, its black screen and its variant", () => {
  page.receive(position({ slide: 3, blank: true, time: 0 }), opener);

  assert.equal(page.body.dataset.blank, "true");
  assert.equal(page.document.documentElement.dataset.scheme, undefined);
});
