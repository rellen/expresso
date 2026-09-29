// The texts of the speaker view. This module does not touch the document, so
// each function has a unit test.

import type { Entry } from "./deck.ts";

// The elapsed time as `m:ss`, or as `h:mm:ss` from one hour. A time less than
// zero gives `0:00`.
export function clock(milliseconds: number): string {
  const total = Math.max(0, Math.floor(milliseconds / 1000));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const seconds = String(total % 60).padStart(2, "0");
  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, "0")}:${seconds}`;
  }
  return `${minutes}:${seconds}`;
}

// The length of the talk in milliseconds, or null for a talk with no length.
// The address parameter `?duration=` gives a number of minutes, and it
// replaces `duration`, the length from the list of the steps. A parameter that
// is not a positive number has no effect. A value such as `1e305` also has no
// effect, because its length in milliseconds is not a finite number.
export function talkLength(
  duration: number | null,
  parameter: string | null,
): number | null {
  const minutes =
    parameter === null || parameter === "" ? NaN : Number(parameter);
  const length = minutes * 60_000;
  if (Number.isFinite(length) && length > 0) {
    return length;
  }
  return duration;
}

// The pace of the talk. `over` is after the end of the time. `behind` means
// that the time that the talk used is more than one minute longer than the
// part of the time for the steps before the current step. `done` is that part
// of the deck, from `done` in `state.ts`.
export type Pace = "on" | "behind" | "over";

// The time that a speaker can be behind and still be on pace.
export const SLACK = 60_000;

export function pace(elapsed: number, total: number, done: number): Pace {
  if (elapsed > total) {
    return "over";
  }
  return elapsed - done * total > SLACK ? "behind" : "on";
}

// The time left, such as `12:34 left`, or the time after the end, such as
// `+1:05 over`. The time left goes up to the next full second, so the timer
// and the time left together always give the length of the talk.
export function left(elapsed: number, total: number): string {
  if (elapsed > total) {
    return `+${clock(elapsed - total)} over`;
  }
  return `${clock(Math.ceil((total - elapsed) / 1000) * 1000)} left`;
}

// The position text of the speaker view: the position of the entry, such as
// `Slide 4 of 13, step 2 of 3`, and a part for a black screen. A deck with no
// slide has no entry.
export function position(entry: Entry | undefined, blank: boolean): string {
  const parts = entry === undefined ? [] : [entry.position];
  if (blank) {
    parts.push("black screen");
  }
  return parts.join(", ");
}
