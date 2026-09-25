import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage, fakeWindow, lastPosition } from "./page.ts";

// The speaker view of three slides of one step each. The present view is the
// window that opened it.
const audience = fakeWindow();
const page = fakePage([1, 1, 1], { search: "?speaker", opener: audience });
const { body } = page;

before(async () => {
  await import("../src/main.ts");
});

test("o in the speaker view sends nothing to the present view", () => {
  const count = audience.received.length;

  page.press("o");
  page.press("ArrowRight");

  assert.equal(body.dataset.overview, "true");
  assert.equal(audience.received.length, count);
});

test("a message from the present view moves the speaker view, and the overview stays", () => {
  page.receive(
    {
      expresso: "position",
      slide: 3,
      step: 1,
      blank: false,
      time: Date.now() + 60_000,
    },
    audience,
  );

  assert.equal(page.location.hash, "#3.1");
  assert.equal(body.dataset.overview, "true");
});

test("Enter in the overview sends the new position to the present view", () => {
  page.press("Home");
  page.press("Enter");

  assert.equal(body.dataset.overview, undefined);
  assert.deepEqual(lastPosition(audience), {
    expresso: "position",
    slide: 1,
    step: 1,
    blank: false,
  });
});
