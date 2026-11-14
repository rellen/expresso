import { test, before, mock } from "node:test";
import assert from "node:assert/strict";
import { fakePage, fakeWindow } from "./page.ts";
import { nth } from "./nth.ts";

// The speaker view of a rehearsal of a deck with two slides. Slide 1 has two
// steps, and each step has a time of 5 seconds from the `advance` option.
// The clock of the test starts at 0, and each test moves it by hand. The
// tests run in sequence on the same page.
mock.timers.enable({ apis: ["Date"], now: 0 });
const opener = fakeWindow();
const page = fakePage([2, 1], {
  search: "?speaker&rehearse",
  hash: "#1.1",
  opener,
  advance: [5000, 5000],
});

before(async () => {
  await import("../src/main.ts");
});

function pass(milliseconds: number): void {
  mock.timers.tick(milliseconds);
  nth(page.timers, 0)();
}

// The dialog of the times: true while it is open.
function open(): boolean {
  return (page.element("times") as unknown as { open: boolean }).open;
}

// The text of each cell of each row of the table.
function table(): string[][] {
  return (page.element("times-rows")?.children ?? []).map((row) =>
    row.children.map((cell) => cell.textContent),
  );
}

function shown(id: string): string | undefined {
  return page.element(id)?.textContent;
}

test("the speaker view of a rehearsal shows a text in the place of the time left", () => {
  pass(0);

  assert.equal(
    shown("speaker-advance"),
    "Rehearsal. Press e for the time of each slide.",
  );
});

test("e before the first change of the step shows a table with no time", () => {
  pass(9000);
  const stopped = page.press("e");

  assert.equal(stopped, true);
  assert.equal(open(), true);
  assert.equal(
    shown("times-total"),
    "No time yet. The timer starts at the first change of the step.",
  );
  assert.deepEqual(table(), [
    ['slide "slide 1"', "2", "No time"],
    ['slide "slide 2"', "1", "No time"],
  ]);
});

test("a second e closes the table", () => {
  page.press("e");

  assert.equal(open(), false);
});

test("a key on an element in the table goes to the browser, and the step stays", () => {
  page.press("e");
  const cell = {
    closest: (selector: string) => (selector === "#times" ? cell : null),
  };

  assert.equal(page.press({ key: "j", target: cell }), false);
  assert.equal(page.location.hash, "#1.1");
  page.press("e");
});

test("the record counts the time of each step from the first change of the step", () => {
  page.press("j");
  pass(12_300);
  page.press("j");
  pass(75_000);
  page.press("e");

  assert.equal(page.location.hash, "#2.1");
  assert.equal(shown("times-total"), "The talk used 1:27.");
  assert.deepEqual(table(), [
    ['slide "slide 1"', "2", "0:12"],
    ['slide "slide 2"', "1", "1:15"],
  ]);
  assert.equal(
    shown("times-code"),
    [
      "# The time of each slide of a talk of 1:27.",
      "# Put each line into its slide.",
      "",
      '# slide "slide 1"',
      "# Step 1 has no time in the record, and 1 second here.",
      "advance [1_000, 12_000]",
      "",
      '# slide "slide 2"',
      "advance 75_000",
      "",
    ].join("\n"),
  );
  page.press("e");
});

test("a step that shows again adds to its time", () => {
  page.press("k");
  pass(8000);
  page.press("k");
  pass(3000);
  page.press("e");

  // Step 1 of slide 1 had no time before, because the timer started at the
  // first change of the step.
  assert.deepEqual(table(), [
    ['slide "slide 1"', "2", "0:23"],
    ['slide "slide 2"', "1", "1:15"],
  ]);
  assert.ok(shown("times-code")?.includes("advance [3_000, 20_000]"));
  page.press("e");
});

test("the clock of the steps does not run in a rehearsal", () => {
  assert.equal(page.timers.length, 1);
  assert.equal(page.location.hash, "#1.1");
});

test("r starts a new record", () => {
  page.press("r");
  page.press("e");

  assert.equal(
    shown("times-total"),
    "No time yet. The timer starts at the first change of the step.",
  );
  page.press("e");

  page.press("j");
  pass(4000);
  page.press("e");
  assert.deepEqual(table(), [
    ['slide "slide 1"', "2", "0:04"],
    ['slide "slide 2"', "1", "No time"],
  ]);
  page.press("e");
});

test("the list of keys shows the key of the times", () => {
  page.press("?");
  const names = page.keys().map((each) => each.names);

  assert.ok(names.includes("e"), "the list has no key e");
});
