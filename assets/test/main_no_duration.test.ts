import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage, fakeWindow } from "./page.ts";

// The speaker view of a deck with no duration and an address with no
// parameter.
const page = fakePage([1, 1], {
  search: "?speaker",
  opener: fakeWindow(),
});

before(async () => {
  await import("../src/main.ts");
});

test("a talk with no length gives no time left and no pace", () => {
  page.press("j");
  page.timers[0]();

  const element = page.element("speaker-left");
  assert.equal(element?.textContent, "");
  assert.equal(element?.dataset.pace, undefined);
});
