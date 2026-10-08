import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage, last } from "./page.ts";
import { nth } from "./nth.ts";

// The present view of a deck with two slides. Slide 1 has two steps.
const page = fakePage([2, 1]);
const { body } = page;

before(async () => {
  await import("../src/main.ts");
});

function sent(field: string): unknown {
  return (last(nth(page.opened, 0).window) as Record<string, unknown>)[field];
}

test("d writes data-undim, and d again removes it", () => {
  page.press("s");
  assert.equal(page.press("d"), true);
  assert.equal(body.dataset.undim, "true");
  assert.equal(sent("undim"), true);

  page.press("d");
  assert.equal(body.dataset.undim, undefined);
  assert.equal(sent("undim"), false);
});

test("the next step removes data-undim, and the message holds false", () => {
  page.press("d");
  page.press("j");

  assert.equal(body.dataset.undim, undefined);
  assert.equal(sent("undim"), false);
  assert.equal(sent("step"), 2);
});

test("a message from the speaker view writes data-undim", () => {
  page.receive(
    {
      expresso: "position",
      slide: 1,
      step: 2,
      blank: false,
      undim: true,
      scheme: null,
      time: Date.now() + 60_000,
    },
    nth(page.opened, 0).window,
  );

  assert.equal(body.dataset.undim, "true");
});
