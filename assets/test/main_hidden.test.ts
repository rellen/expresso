import { test, before, mock } from "node:test";
import assert from "node:assert/strict";
import { fakePage, fakeWindow, lastPosition } from "./page.ts";
import { position } from "./messages.ts";

// The speaker view of a deck with four slides of 1, 2, 1 and 2 steps. Slide 2
// is hidden, so the talk has three slides. The present view opened this
// window. The tests run in sequence on the same page.
const opener = fakeWindow();
const page = fakePage([1, 2, 1, 2], {
  search: "?speaker",
  hash: "#1.1",
  opener,
  hidden: [2],
});

mock.timers.enable({ apis: ["Date"], now: 0 });

before(async () => {
  await import("../src/main.ts");
});

function text(id: string): string | undefined {
  return page.element(id)?.textContent;
}

function marked(): string[] {
  return page.pages.flatMap((each) =>
    each.dataset.speaker === undefined
      ? []
      : [`${each.dataset.speaker} ${each.dataset.slide}.${each.dataset.step}`],
  );
}

test("the next step of the speaker view skips a hidden slide", () => {
  assert.deepEqual(marked(), ["current 1.1", "next 3.1"]);
  assert.equal(text("speaker-position"), "Slide 1 of 3");
});

test("j goes to the next slide of the talk, and the present view gets its place in the deck", () => {
  page.press("j");

  assert.deepEqual(marked(), ["current 3.1", "next 4.1"]);
  assert.equal(text("speaker-position"), "Slide 2 of 3");
  assert.deepEqual(lastPosition(opener), position({ slide: 3 }));
});

test("k goes back to the slide of the talk in front of the hidden slide", () => {
  page.press("k");

  assert.deepEqual(marked(), ["current 1.1", "next 3.1"]);
});

test("a typed number goes to the slide of the talk with that number", () => {
  page.press("3");
  page.press("Enter");

  assert.deepEqual(marked(), ["current 4.1", "next 4.2"]);
  assert.equal(text("speaker-position"), "Slide 3 of 3, step 1 of 2");
});

test("a hidden slide has no number, so the number after the last slide makes no change", () => {
  page.press("4");
  page.press("Enter");

  assert.deepEqual(marked(), ["current 4.1", "next 4.2"]);
});

test("a message from the present view goes to a hidden slide, and j goes through its steps into the talk", () => {
  page.receive(position({ slide: 2, time: Date.now() + 60_000 }), opener);

  assert.deepEqual(marked(), ["current 2.1", "next 2.2"]);
  assert.equal(
    text("speaker-position"),
    "Hidden slide after slide 1 of 3, step 1 of 2",
  );

  page.press("j");
  assert.deepEqual(marked(), ["current 2.2", "next 3.1"]);

  page.press("j");
  assert.deepEqual(marked(), ["current 3.1", "next 4.1"]);
});

test("Home goes to the first slide of the talk, and End goes to its last slide", () => {
  page.press("End");
  assert.deepEqual(marked(), ["current 4.1", "next 4.2"]);

  page.press("Home");
  assert.deepEqual(marked(), ["current 1.1", "next 3.1"]);
});
