// The state of the presenter, the messages between the two windows, and the
// sources of the click events and the swipe events.
//
// This module does not touch the document. `interpreter.ts` changes the state,
// and `dom.ts` applies a state to the document.
//
// The state holds the index of the current step in the list of the steps, and
// the view. `deck.ts` reads the list, and docs/overlays.md gives the rules of a
// step and the reason for the handout view. The program of the presenter
// declares the first value of each field.

import { is } from "./decode.ts";
import type { Deck, Entry } from "./deck.ts";
import type { Program } from "./program.ts";
import { decodeMessage } from "./schema.ts";
import type { Direction, Message, Region, Scheme, State } from "./schema.ts";

// The present view shows one slide at one step. The handout view shows one page
// for each step of each slide. The speaker view shows the current step, the
// next step and the notes, in a second window.
//
// `index` is the index of the current step in the `steps` of the deck. The
// first step of the first slide has the index 0. `blank` is true while the
// present view shows a black screen. `digits` holds the digits of a slide
// number that the presenter types before `Enter`.
// `help` is true while the view shows the list of its keys. `progress` is
// true while the present view shows the progress bar. `every` is true while
// the handout view, and a print, show every step and not only the steps that
// the `handout` option of each slide selects. `overview` is true while the
// present view or the speaker view shows a grid of the slides. `selected` is
// the number of the selected slide in that grid. A message does not hold the
// overview, so the overview shows only in the window that opens it.
//
// `schema.ts` declares `View` and `State`.
export type { State, View } from "./schema.ts";

// The entry of the current step, or undefined for a deck with no slide.
export function current(state: State, deck: Deck): Entry | undefined {
  return deck.steps[state.index];
}

// The part of the window under a click or a tap at `x` pixels from the left
// edge of a window of `width` pixels. The left third goes back, because the
// presenter clicks to go forward more frequently than to go back.
export function side(x: number, width: number): Region {
  return x < width / 3 ? "left_third" : "right";
}

// The minimum horizontal distance of a swipe, in pixels.
export const SWIPE = 50;

// The direction of a movement of a finger across the screen. A swipe to the
// left goes forward, as on a page of a book. A short movement or a movement
// that is more vertical than horizontal is not a swipe.
export function swipe(dx: number, dy: number): Direction | undefined {
  if (Math.abs(dx) < SWIPE || Math.abs(dx) <= Math.abs(dy)) {
    return undefined;
  }
  return dx < 0 ? "left" : "right";
}

// The message that one window of the presenter sends to the other window
// after each change of its own. The speaker view and the present view then show
// the same step, and the key `b` in either window gives a black screen to the
// audience. `fields` holds each field of the option `sync` of the presenter,
// such as the dimming of code that the key `d` turns off. The message also
// holds the variant of the theme that the key `t` chose, so the two windows
// show the same variant.
//
// `time` is the time of the change in milliseconds. A window does not send a
// position from the other window back, and it ignores a message that is older
// than its own state. Two keys that come faster than a message can then give
// no loop: before this rule, the echo of the first key came back after the
// second key, and the two windows sent the two positions to each other with
// no end.
//
// `schema.ts` declares `Message`.
export type { Message } from "./schema.ts";

export function message(
  program: Program,
  state: State,
  deck: Deck,
  time: number,
  scheme: Scheme,
): Message {
  const entry = current(state, deck);
  return {
    expresso: "position",
    slide: entry?.slide ?? 1,
    step: entry?.step ?? 1,
    fields: Object.fromEntries(
      program.sync.map((field) => [field, state[field]]),
    ),
    scheme,
    time,
  };
}

// Tell if a change of this window goes to the other window: a change of the
// step, or of a field of the option `sync`.
export function synced(program: Program, before: State, after: State): boolean {
  return (
    after.index !== before.index ||
    program.sync.some((field) => after[field] !== before[field])
  );
}

// The time of a change of this window: the clock, or one more than the time of
// the state before it, so that the times of one window always increase. The two
// windows read the same clock, so the time orders the changes of both.
export function stamp(last: number, now: number): number {
  return Math.max(now, last + 1);
}

// Tell if a window takes a message with the time `incoming`, when its own state
// has the time `own`. A newer message wins. At the same time, the speaker view
// takes the state of the present view, and the present view keeps its own, so
// the two windows always end at the same state.
export function accepts(
  own: number,
  incoming: number,
  speaker: boolean,
): boolean {
  return incoming > own || (incoming === own && speaker);
}

// Tell if data from the other window is a message of the presenter. The other
// window and the extensions of the browser can send any value, so the script
// decodes each message.
export function isMessage(data: unknown): data is Message {
  return is(decodeMessage, data);
}
