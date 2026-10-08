import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage, last } from "./page.ts";
import { nth } from "./nth.ts";
import type { Field, Message } from "../src/schema.ts";
import { position } from "./messages.ts";

// The present view of a deck with two slides. Slide 1 has two steps.
const page = fakePage([2, 1]);
const { body } = page;

before(async () => {
  await import("../src/main.ts");
});

// A field of the last message to the speaker view.
function sent(field: string): unknown {
  return (last(nth(page.opened, 0).window) as Message).fields[field as Field];
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
  assert.equal((last(nth(page.opened, 0).window) as Message).step, 2);
});

test("a message from the speaker view writes data-undim", () => {
  page.receive(
    position({ step: 2, undim: true, time: Date.now() + 60_000 }),
    nth(page.opened, 0).window,
  );

  assert.equal(body.dataset.undim, "true");
});
