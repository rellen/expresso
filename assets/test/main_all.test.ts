import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage } from "./page.ts";

// The address holds `?all`, so the handout view and a print show every step.
const page = fakePage([1, 2], { search: "?all" });

before(async () => {
  await import("../src/main.ts");
});

test("?all shows every step at load, in the present view", () => {
  assert.equal(page.body.dataset.every, "true");
  assert.equal(page.body.dataset.view, "present");
});

test("a in the handout view still shows the selection", () => {
  page.press("p");
  page.press("a");

  assert.equal(page.body.dataset.every, "false");
});

test("the speaker view opens with ?all in its address", () => {
  page.press("p");
  page.press("s");

  assert.equal(page.opened[0].url, "file:///deck.html?all=&speaker=#1.1");
});
