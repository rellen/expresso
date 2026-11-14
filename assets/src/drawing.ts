// The drawing: the lines that the presenter draws on a slide during the talk,
// with a pen or with a highlighter.
//
// This module does not touch the document. `main.ts` reads the events of the
// pointer and keeps the lines, and `dom.ts` writes them into the element
// `drawing`. The key `x` of the presenter program changes the field `draw` of
// the state, the key `h` changes the field `highlighter`, and the key `c`
// calls the built-in function `clear_drawing`.
//
// A line holds its tool and its points. Each point is a part of the box of
// the slide, from 0 to 1 in each direction, as the place of the laser
// pointer is. The two windows can have different sizes, and a line is then on
// the same part of the slide in each one. The drawing belongs to the slide
// that shows: a change of the step keeps it, and a change of the slide
// removes it. docs/drawing.md gives the design.

import { is } from "./decode.ts";
import type { Place } from "./laser.ts";
import { decodeDrawing } from "./schema.ts";
import type { Drawing, Line, State } from "./schema.ts";

// `schema.ts` declares `Line`, one line of a drawing, and `Drawing`, the
// message of one window to the other window when the drawing changes.
export type { Drawing, Line } from "./schema.ts";

// The pen draws a thin line, and the highlighter draws a wide line that the
// content of the slide shows through.
export type Tool = Line["tool"];

// The minimum distance between two points of a line, as a part of the slide.
// A slow drag gives many events at almost the same place, and a point for
// each one makes the message large with no change that the eye sees.
export const STEP = 0.002;

// Tell if the drawing is on and the window shows a slide. The presenter
// cannot draw on a black screen, in the overview, in the menu, in the list
// of keys or in the handout view. While this function is true, a click or a
// swipe draws, and it does not change the step.
export function drawing(state: State): boolean {
  return (
    state.draw &&
    (state.view === "present" || state.view === "speaker") &&
    !state.blank &&
    !state.overview &&
    !state.menu &&
    !state.help
  );
}

// The tool of the next line.
export function tool(state: State): Tool {
  return state.highlighter ? "highlighter" : "pen";
}

// A new line with one point.
export function start(tool: Tool, place: Place): Line {
  return { tool, points: [[place.x, place.y]] };
}

// A line with one more point. A place that is nearer than `STEP` to the last
// point returns the same line.
export function extend(line: Line, place: Place): Line {
  const last = line.points[line.points.length - 1];
  if (
    last !== undefined &&
    Math.hypot(place.x - last[0], place.y - last[1]) < STEP
  ) {
    return line;
  }
  return { ...line, points: [...line.points, [place.x, place.y]] };
}

// The place on the slide that is nearest to a point of the window. A drag
// that goes past an edge of the slide continues along that edge.
export function nearest(
  x: number,
  y: number,
  box: Readonly<{ left: number; top: number; width: number; height: number }>,
): Place {
  const part = (value: number, size: number) =>
    size <= 0 ? 0 : Math.min(1, Math.max(0, value / size));
  return {
    x: part(x - box.left, box.width),
    y: part(y - box.top, box.height),
  };
}

// The attribute `d` of the SVG path of a line. The path is in a box from 0
// to 1 in each direction, and each number has four decimal places at most.
// A line with one point goes to the same point again, so the round end of
// its stroke shows a dot.
export function path(line: Line): string {
  const number = (value: number) => String(Math.round(value * 10000) / 10000);
  const points = line.points.map(([x, y]) => `${number(x)} ${number(y)}`);
  const [first, ...rest] = points;
  if (first === undefined) {
    return "";
  }
  return `M${first}L${(rest.length === 0 ? [first] : rest).join("L")}`;
}

// The message for the lines of the drawing of the current slide.
export function message(lines: readonly Line[]): Drawing {
  return { expresso: "drawing", lines };
}

// Tell if data from the other window is a message of the drawing. The other
// window and the extensions of the browser can send any value, so the script
// decodes each message.
export function isDrawing(data: unknown): data is Drawing {
  return is(decodeDrawing, data);
}
