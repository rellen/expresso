import { test } from "node:test";
import assert from "node:assert/strict";
import {
  begin,
  code,
  counted,
  label,
  literal,
  missing,
  move,
  option,
  rounded,
  rows,
  summary,
  total,
  waiting,
} from "../src/rehearse.ts";
import { deckOf } from "./decks.ts";

// Three slides of 1, 3 and 1 steps.
const deck = deckOf([1, 3, 1]);

test("waiting gives a record with no time, and the timer does not run", () => {
  assert.deepEqual(waiting(2), { spent: [], index: 2, since: null });
  assert.deepEqual(counted(waiting(2), 9000), []);
});

test("a move before the start of the timer counts no time", () => {
  const moved = move(waiting(0), 1, 5000);

  assert.deepEqual(moved, { spent: [], index: 1, since: null });
});

test("begin counts the step that shows from the start of the timer", () => {
  const times = begin(1, 1000);

  assert.deepEqual(times, { spent: [], index: 1, since: 1000 });
  assert.deepEqual(counted(times, 4000), [undefined, 3000]);
});

test("move gives the step before it the time that it used", () => {
  const times = move(begin(1, 1000), 2, 4000);

  assert.deepEqual(times, {
    spent: [undefined, 3000],
    index: 2,
    since: 4000,
  });
  assert.deepEqual(counted(times, 6000), [undefined, 3000, 2000]);
});

test("a step that shows a second time adds to its time", () => {
  const forward = move(begin(1, 1000), 2, 4000);
  const back = move(forward, 1, 6000);
  const again = move(back, 2, 7500);

  assert.deepEqual(again.spent, [undefined, 4500, 2000]);
});

test("counted does not count a time before the start of the step", () => {
  assert.deepEqual(counted(begin(0, 5000), 4000), [0]);
});

test("rows gives the time of each step of each slide, and the sum", () => {
  const table = rows(deck, [undefined, 3000, 2000, undefined, 9000]);

  assert.deepEqual(table, [
    { place: 1, name: "slide 1", number: 1, steps: [0], time: 0 },
    {
      place: 2,
      name: "slide 2",
      number: 2,
      steps: [3000, 2000, 0],
      time: 5000,
    },
    { place: 3, name: "slide 3", number: 3, steps: [9000], time: 9000 },
  ]);
  assert.equal(total(table), 14_000);
});

test("rows gives a hidden slide no number", () => {
  const hidden = deckOf([1, 1], { hidden: [2] });

  assert.deepEqual(
    rows(hidden, []).map((row) => row.number),
    [1, null],
  );
});

test("rounded gives the nearest full second, and one second at least", () => {
  assert.equal(rounded(31_600), 32_000);
  assert.equal(rounded(31_499), 31_000);
  assert.equal(rounded(1499), 1000);
  assert.equal(rounded(400), 1000);
  assert.equal(rounded(0), 1000);
});

test("literal writes an integer as Elixir does", () => {
  assert.equal(literal(1000), "1_000");
  assert.equal(literal(32_000), "32_000");
  assert.equal(literal(1_200_000), "1_200_000");
  assert.equal(literal(500), "500");
});

test("option gives one time for a slide with one step", () => {
  assert.equal(option([31_600]), "32_000");
});

test("option gives one time when each step has the same time", () => {
  assert.equal(option([8200, 7900, 8000]), "8_000");
});

test("option gives a list when the steps have different times", () => {
  assert.equal(option([12_300, 8000, 400]), "[12_000, 8_000, 1_000]");
});

test("option gives false for a slide with no time", () => {
  assert.equal(option([0]), "false");
  assert.equal(option([0, 0]), "false");
});

test("label gives the name of a slide, or its place for a slide with no name", () => {
  const [row] = rows(deck, []);
  assert.ok(row);

  assert.equal(label(row), 'slide "slide 1"');
  assert.equal(label({ ...row, name: null }), "slide 1");
});

test("missing names each step with no time of a slide with a time", () => {
  assert.equal(
    missing([0, 12_000]),
    "# Step 1 has no time in the record, and 1 second here.",
  );
  assert.equal(
    missing([0, 12_000, 0]),
    "# The steps 1, 3 have no time in the record, and 1 second here.",
  );
});

test("missing gives no comment for a slide with a time for each step, or with no time", () => {
  assert.equal(missing([3000, 12_000]), null);
  assert.equal(missing([0, 0]), null);
  assert.equal(missing([0]), null);
});

test("code gives a comment and a line of the advance option for each slide", () => {
  const table = rows(deck, [undefined, 12_300, 8000, 0, 75_000]);

  assert.equal(
    code(table),
    [
      "# The time of each slide of a talk of 1:35.",
      "# Put each line into its slide.",
      "",
      '# slide "slide 1"',
      "advance false",
      "",
      '# slide "slide 2"',
      "# Step 3 has no time in the record, and 1 second here.",
      "advance [12_000, 8_000, 1_000]",
      "",
      '# slide "slide 3"',
      "advance 75_000",
      "",
    ].join("\n"),
  );
});

test("summary gives the time of the talk, or the reason for no time", () => {
  assert.equal(summary(rows(deck, [0, 3000, 62_000])), "The talk used 1:05.");
  assert.equal(
    summary(rows(deck, [])),
    "No time yet. The timer starts at the first change of the step.",
  );
});
