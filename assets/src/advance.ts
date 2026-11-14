// The clock of the steps: a step with a time goes to the next step when its
// time ends.
//
// This module does not touch the document. The option `advance` of a slide
// or of the deck gives each step a time, and `Expresso.Steps` writes that
// time into the entry of the step. `main.ts` keeps one clock for the step
// that shows. The present view goes to the next step when the time ends, and
// the speaker view shows the time left.
//
// The clock runs while the window shows the present view or the speaker
// view, with no black screen, and while the field `paused` of the state is
// false. The key `a` of the presenter program changes that field, and the
// program sends it to the other window as it sends each field of the option
// `sync`. Each window thus has the same clock, with the small difference of
// the time of a message. A new step starts its time from zero, and a clock
// that starts again continues the time of its step.
// docs/timed-advance.md gives the design.

import type { Entry } from "./deck.ts";
import { clock as time } from "./speaker.ts";
import type { State } from "./state.ts";

// The clock of one step: the index of the step, the time that the step used
// before the clock stopped the last time, and the time of the last start, or
// null while the clock does not run. Each time is in milliseconds.
export type Clock = Readonly<{
  index: number;
  spent: number;
  since: number | null;
}>;

// Tell if the clock of the steps runs in a state.
export function runs(state: State): boolean {
  return (
    !state.paused &&
    !state.blank &&
    (state.view === "present" || state.view === "speaker")
  );
}

// The clock of a step at its start.
export function start(index: number, running: boolean, now: number): Clock {
  return { index, spent: 0, since: running ? now : null };
}

// The clock after a change of the state. A different step starts its time
// from zero. A clock that stops keeps the time that the step used, and a
// clock that starts again continues from it.
export function update(
  clock: Clock,
  index: number,
  running: boolean,
  now: number,
): Clock {
  if (index !== clock.index) {
    return start(index, running, now);
  }
  if (running && clock.since === null) {
    return { ...clock, since: now };
  }
  if (!running && clock.since !== null) {
    return { index, spent: used(clock, now), since: null };
  }
  return clock;
}

// The time that the step of a clock used.
export function used(clock: Clock, now: number): number {
  const running = clock.since === null ? 0 : Math.max(0, now - clock.since);
  return clock.spent + running;
}

// The time left of the step of a clock, or null for a step that waits for a
// key: a step with no time, and a step with no different step after it,
// such as the last step of a deck with no option `loop`.
export function left(
  clock: Clock,
  entry: Entry | undefined,
  now: number,
): number | null {
  if (
    entry === undefined ||
    entry.advance === null ||
    entry.next === null ||
    entry.next === clock.index
  ) {
    return null;
  }
  return Math.max(0, entry.advance - used(clock, now));
}

// Tell if the time of the step ended while the clock runs.
export function due(
  clock: Clock,
  entry: Entry | undefined,
  now: number,
): boolean {
  return clock.since !== null && left(clock, entry, now) === 0;
}

// The text of the speaker view for the time left of a step, such as
// `Next step in 0:12`, or the empty text for a step that waits for a key.
// The time goes up to the next full second, so the text shows `0:01` in the
// last second of the step.
export function text(remaining: number | null, running: boolean): string {
  if (remaining === null) {
    return "";
  }
  const shown = time(Math.ceil(remaining / 1000) * 1000);
  return running
    ? `Next step in ${shown}`
    : `Clock stopped, ${shown} to the next step`;
}
