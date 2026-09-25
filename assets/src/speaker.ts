// The texts of the speaker view. This module does not touch the document, so
// each function has a unit test.

import { maxStep } from "./state.ts";
import type { Limits, State } from "./state.ts";

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
// The address parameter `?duration=` replaces the attribute `data-duration`
// of the `body`. Each value is a number of minutes. A value that is not a
// positive number has no effect.
export function talkLength(
  attribute: string | undefined,
  parameter: string | null,
): number | null {
  for (const value of [parameter, attribute]) {
    const minutes = value === null || value === undefined ? NaN : Number(value);
    if (value !== "" && Number.isFinite(minutes) && minutes > 0) {
      return minutes * 60_000;
    }
  }
  return null;
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

// The position of the state, such as `Slide 4 of 13, step 2 of 3`. A slide
// with one step gets no step part. A black screen adds a part.
export function describe(state: State, limits: Limits): string {
  const parts = [`Slide ${state.slide} of ${limits.slides}`];
  const steps = maxStep(state.slide, limits);
  if (steps > 1) {
    parts.push(`step ${state.step} of ${steps}`);
  }
  if (state.blank) {
    parts.push("black screen");
  }
  return parts.join(", ");
}
