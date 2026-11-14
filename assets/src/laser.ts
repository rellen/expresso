// The laser pointer: a dot that goes with the mouse or with a finger while
// the field `laser` of the state is true.
//
// This module does not touch the document. `main.ts` reads the events of the
// pointer, and `dom.ts` moves the dot. The key `l` of the presenter program
// changes the field, and the program sends it to the other window as it sends
// each field of the option `sync`. A change of the step turns the pointer
// off, because `laser` is also a field of the option `reset`.
//
// The place of the dot is a part of the box of the slide, from 0 to 1 in
// each direction. The box of the slide is the window in the present view,
// and the page of the current step in the speaker view. The two windows can
// have different sizes, and the dot is then on the same part of the slide in
// each one. docs/laser-pointer.md gives the design.

import { is } from "./decode.ts";
import { decodePointer } from "./schema.ts";
import type { Pointer, State } from "./schema.ts";

// A place on the slide, as a part of its width and of its height.
export type Place = Readonly<{ x: number; y: number }>;

// The box of the slide in the window, in pixels. A `DOMRect` is such a box.
export type Box = Readonly<{
  left: number;
  top: number;
  width: number;
  height: number;
}>;

// `schema.ts` declares `Pointer`, the message of one window to the other
// window when the dot moves.
export type { Pointer } from "./schema.ts";

// Tell if the pointer is on and the window shows a slide. The pointer does
// not show on a black screen, in the overview, in the menu, in the list of
// keys or in the handout view. While this function is true, a click or a
// swipe moves the dot, and it does not change the step.
export function pointing(state: State): boolean {
  return (
    state.laser &&
    (state.view === "present" || state.view === "speaker") &&
    !state.blank &&
    !state.overview &&
    !state.menu &&
    !state.help
  );
}

// The place of a point of the window on the slide, or null for a point that
// is not in the box of the slide, and for a view with no such box.
export function placeIn(x: number, y: number, box: Box | null): Place | null {
  if (box === null || box.width <= 0 || box.height <= 0) {
    return null;
  }
  const place = {
    x: (x - box.left) / box.width,
    y: (y - box.top) / box.height,
  };
  const inside = place.x >= 0 && place.x <= 1 && place.y >= 0 && place.y <= 1;
  return inside ? place : null;
}

// The point of the window for a place on the slide, in pixels.
export function pointOf(
  place: Place,
  box: Box,
): Readonly<{ left: number; top: number }> {
  return {
    left: box.left + place.x * box.width,
    top: box.top + place.y * box.height,
  };
}

// The message for a place of the dot, or for no dot.
export function pointer(place: Place | null): Pointer {
  return { expresso: "pointer", x: place?.x ?? null, y: place?.y ?? null };
}

// Tell if data from the other window is a message of the laser pointer. The
// other window and the extensions of the browser can send any value, so the
// script decodes each message.
export function isPointer(data: unknown): data is Pointer {
  return is(decodePointer, data);
}

// The place of a message, or null for a message with no dot.
export function placeOf(message: Pointer): Place | null {
  return message.x === null || message.y === null
    ? null
    : { x: message.x, y: message.y };
}
