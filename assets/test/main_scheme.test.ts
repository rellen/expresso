import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage, last } from "./page.ts";
import { nth } from "./nth.ts";

// The present view of a deck with a light and a dark variant, on a screen with
// a dark scheme. The address chooses the light variant.
const page = fakePage([1, 2], {
  search: "?scheme=light",
  variants: true,
  dark: true,
});
const root = page.document.documentElement;

before(async () => {
  await import("../src/main.ts");
});

function scheme(window: Parameters<typeof last>[0]): unknown {
  return (last(window) as Record<string, unknown>).scheme;
}

test("the address chooses the variant at the load", () => {
  assert.equal(root.dataset.scheme, "light");
});

test("s gives the variant to the speaker view in its address", () => {
  page.press("s");

  assert.equal(
    nth(page.opened, 0).url,
    "file:///deck.html?scheme=light&speaker=#1.1",
  );
});

test("t shows the other variant, and sends it to the speaker view", () => {
  const speaker = nth(page.opened, 0).window;
  page.press("t");

  assert.equal(root.dataset.scheme, "dark");
  assert.equal(scheme(speaker), "dark");
});

test("a move sends the variant of the window", () => {
  const speaker = nth(page.opened, 0).window;
  page.press("j");

  assert.equal(scheme(speaker), "dark");
});

test("a message from the speaker view changes the variant", () => {
  const speaker = nth(page.opened, 0).window;
  page.receive(
    {
      expresso: "position",
      slide: 2,
      step: 1,
      blank: false,
      scheme: null,
      time: Date.now() + 60_000,
    },
    speaker,
  );

  assert.equal(root.dataset.scheme, undefined);
});
