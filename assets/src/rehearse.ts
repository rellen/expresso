// The rehearsal: the time that each slide of a talk used, and the lines of
// the `advance` option that give a deck those times.
//
// This module does not touch the document. The speaker view keeps a record
// while its timer runs, and the key `e` shows a table of the times in the
// dialog `times`. `main.ts` moves the record, and `dom.ts` writes the table.
// The timer starts at the first change of the step, so the step that shows
// before that change has no time. The key `r` starts a new record.
//
// `?rehearse` in the address is the rehearsal: the clock of the steps does
// not run, so the presenter gives each step its time with the keys.
// docs/rehearsal.md gives the design.

import type { Deck } from "./deck.ts";
import { clock } from "./speaker.ts";

// The record of a talk: the time that each step used, at the index of the
// step in the list of the steps, the index of the step that shows, and the
// time when that step started to count, or null while the timer does not
// run. Each time is in milliseconds. A step with no time has no value.
export type Times = Readonly<{
  spent: readonly (number | undefined)[];
  index: number;
  since: number | null;
}>;

// The record before the start of the timer.
export function waiting(index: number): Times {
  return { spent: [], index, since: null };
}

// The record at the start of the timer. The step that shows counts from
// that time.
export function begin(index: number, now: number): Times {
  return { spent: [], index, since: now };
}

// The time that each step used until a time: the record, with the time of
// the step that shows.
export function counted(
  times: Times,
  now: number,
): readonly (number | undefined)[] {
  if (times.since === null) {
    return times.spent;
  }
  // The list has a value at each index up to the step that shows, so it has
  // no place with no value.
  const length = Math.max(times.spent.length, times.index + 1);
  const spent = Array.from({ length }, (_none, index) => times.spent[index]);
  spent[times.index] =
    (spent[times.index] ?? 0) + Math.max(0, now - times.since);
  return spent;
}

// The record after a move to a step. The step before the move keeps the
// time that it used, and a step that shows a second time adds to its time.
export function move(times: Times, index: number, now: number): Times {
  return {
    spent: counted(times, now),
    index,
    since: times.since === null ? null : now,
  };
}

// One slide of the table: its place in the deck, its name, its number in
// the talk, or null for a hidden slide, the time of each of its steps, and
// their sum.
export type Row = Readonly<{
  place: number;
  name: string | null;
  number: number | null;
  steps: readonly number[];
  time: number;
}>;

// A row for each slide of a deck.
export function rows(
  deck: Deck,
  spent: readonly (number | undefined)[],
): Row[] {
  return deck.slides.map((slide, index) => {
    const steps = Array.from(
      { length: slide.steps },
      (_none, step) => spent[slide.first + step] ?? 0,
    );
    return {
      place: index + 1,
      name: slide.name,
      number: slide.number,
      steps,
      time: steps.reduce((sum, time) => sum + time, 0),
    };
  });
}

// The time of the talk: the sum of each row.
export function total(table: readonly Row[]): number {
  return table.reduce((sum, row) => sum + row.time, 0);
}

// A time of a step for the `advance` option: the nearest full second, and
// one second for a shorter time, because the option takes no zero.
export function rounded(milliseconds: number): number {
  return Math.max(1000, Math.round(milliseconds / 1000) * 1000);
}

// An integer as Elixir writes it, with an underscore in front of each group
// of three digits, such as `32_000`.
export function literal(value: number): string {
  return String(value).replace(/\B(?=(\d{3})+$)/g, "_");
}

// The value of the `advance` option for the times of the steps of a slide:
// `false` for a slide with no time, one time when each step has the same
// time, and a list of times in the other cases.
export function option(steps: readonly number[]): string {
  if (steps.every((time) => time <= 0)) {
    return "false";
  }
  const times = steps.map(rounded);
  const [first] = times;
  if (first !== undefined && times.every((time) => time === first)) {
    return literal(first);
  }
  return `[${times.map(literal).join(", ")}]`;
}

// The name of a slide in a comment and in the table: its name, or its place
// in the deck for a slide with no name.
export function label(row: Row): string {
  return row.name === null ? `slide ${row.place}` : `slide "${row.name}"`;
}

// The comment for the steps of a slide that have no time in the record,
// while a different step of the slide has one, or null. Such a step shows
// before the start of the timer, or the presenter did not go to it. The
// option takes no zero, so the step gets one second.
export function missing(steps: readonly number[]): string | null {
  const numbers = steps.flatMap((time, index) => (time > 0 ? [] : [index + 1]));
  if (numbers.length === 0 || numbers.length === steps.length) {
    return null;
  }
  const names =
    numbers.length === 1
      ? `Step ${numbers[0]} has`
      : `The steps ${numbers.join(", ")} have`;
  return `# ${names} no time in the record, and 1 second here.`;
}

// The lines of the `advance` option for a deck: a comment with the time of
// the talk, and for each slide a comment with its name and the line of its
// option. The author puts each line into its slide.
export function code(table: readonly Row[]): string {
  const head = [
    `# The time of each slide of a talk of ${clock(total(table))}.`,
    "# Put each line into its slide.",
  ];
  const slides = table.map((row) =>
    [
      "",
      `# ${label(row)}`,
      ...[missing(row.steps)].filter((line) => line !== null),
      `advance ${option(row.steps)}`,
    ].join("\n"),
  );
  return [...head, ...slides].join("\n") + "\n";
}

// The sentence above the table: the time of the talk, or the reason for a
// table with no time.
export function summary(table: readonly Row[]): string {
  const time = total(table);
  return time > 0
    ? `The talk used ${clock(time)}.`
    : "No time yet. The timer starts at the first change of the step.";
}

// The text of the speaker view in a rehearsal, in the place of the time
// left of a step.
export const HINT = "Rehearsal. Press e for the time of each slide.";
