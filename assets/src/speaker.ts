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
