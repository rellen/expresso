// The zoom: a part of the slide that fills the window.
//
// This module does not touch the document. `main.ts` reads the click, and
// `dom.ts` writes the scale and the move of the slide for the style sheet. A
// click with the Alt key zooms to the part of the slide under the mouse, and
// the next such click shows the full slide again. The key `z` of the
// presenter program changes the field `zoom` of the state, and a click with
// no key then does the same. The program sends the field to the other window
// as it sends each field of the option `sync`. A change of the step turns
// the field off, because `zoom` is also a field of the option `reset`.
//
// An area is a rectangle on the slide, and each of its values is a part of
// the width or of the height of the slide, from 0 to 1. The two windows can
// have different sizes, and the same part of the slide then fills each one.
// An element of the slide gives its box with a margin. A click outside each
// element gives the area of the factor 2 around the point.
// docs/zoom.md gives the design.

import { is } from "./decode.ts";
import { decodeZoom } from "./schema.ts";
import type { Area, State, Zoom } from "./schema.ts";
import type { Box, Place } from "./laser.ts";

// `schema.ts` declares `Area`, and `Zoom`, the message of one window to the
// other window when the zoom changes.
export type { Area, Zoom } from "./schema.ts";

// The scale of the slide, and the move of its top left corner as a part of
// its width and of its height. The style sheet makes the transform from the
// three values.
export type Scale = Readonly<{ scale: number; x: number; y: number }>;

// The scale of a click outside each element.
export const FACTOR = 2;

// The largest scale. A small element, such as an icon, does not fill the
// window.
export const LIMIT = 4;

// The space around an element, as a part of the slide.
export const MARGIN = 0.02;

// The smallest scale that an element can give. An element that fills most of
// the slide gives a smaller scale, and the click then zooms around the point.
export const LEAST = 1.25;

// Tell if the window shows a slide that can zoom. The overview, the menu,
// the list of keys, a black screen and the handout view show no zoom.
export function zoomable(state: State): boolean {
  return (
    (state.view === "present" || state.view === "speaker") &&
    !state.blank &&
    !state.overview &&
    !state.menu &&
    !state.help
  );
}

// Tell if the zoom is on and the window shows a slide. While this function
// is true, a click or a tap zooms, and it does not change the step.
export function zooming(state: State): boolean {
  return state.zoom && zoomable(state);
}

function clamp(value: number, least: number, most: number): number {
  return Math.min(Math.max(value, least), most);
}

// The area of the factor 2 around a place. An area near an edge of the
// slide stays on the slide.
export function around(place: Place): Area {
  const size = 1 / FACTOR;
  return {
    x: clamp(place.x - size / 2, 0, 1 - size),
    y: clamp(place.y - size / 2, 0, 1 - size),
    width: size,
    height: size,
  };
}

// The area of an element of the slide, with the margin, or null for an
// element that gives a scale less than `LEAST`.
export function areaOf(element: Box, slide: Box): Area | null {
  if (slide.width <= 0 || slide.height <= 0) {
    return null;
  }
  const left = (element.left - slide.left) / slide.width;
  const top = (element.top - slide.top) / slide.height;
  const x = clamp(left - MARGIN, 0, 1);
  const y = clamp(top - MARGIN, 0, 1);
  const area = {
    x,
    y,
    width: clamp(left + element.width / slide.width + MARGIN, 0, 1) - x,
    height: clamp(top + element.height / slide.height + MARGIN, 0, 1) - y,
  };
  const visible = area.width > 0 && area.height > 0;
  return visible && scaleOf(area).scale >= LEAST ? area : null;
}

// The area of a click: the element under the click, or the area around the
// place of the click when no element gives an area.
export function target(place: Place, element: Box | null, slide: Box): Area {
  return (element === null ? null : areaOf(element, slide)) ?? around(place);
}

// The scale that makes an area fill the slide in one direction, and the move
// that puts the center of the area at the center of the slide. The scale is
// not more than `LIMIT`. The move keeps each edge of the slide at an edge of
// the window or outside it, so the window shows no space outside the slide.
export function scaleOf(area: Area): Scale {
  const fit = Math.min(1 / area.width, 1 / area.height);
  const scale = clamp(Number.isFinite(fit) ? fit : LIMIT, 1, LIMIT);
  const move = (start: number, size: number): number =>
    clamp(0.5 - (start + size / 2) * scale, 1 - scale, 0);
  return {
    scale,
    x: move(area.x, area.width),
    y: move(area.y, area.height),
  };
}

// The message for an area, or for the full slide.
export function message(area: Area | null): Zoom {
  return { expresso: "zoom", area };
}

// Tell if data from the other window is a message of the zoom. The other
// window and the extensions of the browser can send any value, so the script
// decodes each message.
export function isZoom(data: unknown): data is Zoom {
  return is(decodeZoom, data);
}
