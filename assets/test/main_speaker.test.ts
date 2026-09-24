import { test, before, mock } from "node:test";
import assert from "node:assert/strict";
import { fakePage, fakeWindow, lastPosition } from "./page.ts";

// The speaker view of a deck with two slides. Slide 1 has two steps and notes,
// and slide 2 has one step and no notes. The present view opened this window.
const opener = fakeWindow();
const page = fakePage([2, 1], {
  search: "?speaker",
  hash: "#1.1",
  opener,
  notes: ["Say hello."],
});

// The clock of the timer starts at 0, and each test moves it by hand.
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

test("the speaker view shows the current step, the next step and the notes", () => {
  assert.equal(page.body.dataset.view, "speaker");
  assert.equal(page.document.title, "Speaker view: Deck");
  assert.deepEqual(marked(), ["current 1.1", "next 1.2"]);
  assert.equal(text("speaker-notes"), "Say hello.");
  assert.equal(text("speaker-position"), "Slide 1 of 2, step 1 of 2");
  assert.equal(text("speaker-timer"), "0:00");
});

test("the timer waits for the first change of the step", () => {
  mock.timers.tick(5000);
  page.timers[0]();

  assert.equal(text("speaker-timer"), "0:00");
});

test("a key moves the speaker view, and the present view gets the change", () => {
  page.press("j");

  assert.deepEqual(marked(), ["current 1.2", "next 2.1"]);
  assert.deepEqual(lastPosition(opener), {
    expresso: "position",
    slide: 1,
    step: 2,
    blank: false,
  });
});

test("the last step has no next step, and a slide without notes has no notes", () => {
  // The clock of the test starts at 0, so a time of one million is after each
  // change of the speaker view.
  page.receive(
    { expresso: "position", slide: 2, step: 1, blank: false, time: 1_000_000 },
    opener,
  );

  assert.deepEqual(marked(), ["current 2.1"]);
  assert.equal(text("speaker-notes"), "");
  assert.equal(text("speaker-position"), "Slide 2 of 2");
});

test("p and s have no function in the speaker view", () => {
  assert.equal(page.press("p"), false);
  assert.equal(page.press("s"), false);
  assert.equal(page.body.dataset.view, "speaker");
  assert.deepEqual(page.opened, []);
});

test("b gives a black screen to the present view", () => {
  page.press("b");

  assert.deepEqual(lastPosition(opener), {
    expresso: "position",
    slide: 2,
    step: 1,
    blank: true,
  });
  assert.equal(text("speaker-position"), "Slide 2 of 2, black screen");
  page.press("x");
});

test("the timer counts from the first change of the step", () => {
  mock.timers.tick(61_000);
  page.timers[0]();

  assert.equal(text("speaker-timer"), "1:01");
});

test("r sets the timer back to 0:00, and the next change starts it again", () => {
  assert.equal(page.press("r"), true);
  mock.timers.tick(10_000);
  page.timers[0]();
  assert.equal(text("speaker-timer"), "0:00");

  page.press("k");
  mock.timers.tick(2_000);
  page.timers[0]();
  assert.equal(text("speaker-timer"), "0:02");
});

test("? lists r in the speaker view, and r then only closes the list", () => {
  page.press("?");
  const panel = page.element("help");
  assert.ok(panel, "no element help");
  const names = panel.children.map((row) => row.children[0].textContent);
  assert.ok(names.includes("r"));
  assert.ok(!names.includes("s"));

  page.press("k");
  mock.timers.tick(3_000);
  page.press("?");
  page.press("r");
  page.timers[0]();
  assert.equal("help" in page.body.dataset, false);
  assert.notEqual(text("speaker-timer"), "0:00");
});
