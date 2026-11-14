import { test } from "node:test";
import assert from "node:assert/strict";
import {
  drawing,
  extend,
  isDrawing,
  message,
  nearest,
  path,
  start,
  STEP,
  tool,
} from "../src/drawing.ts";
import { deckOf, at } from "./decks.ts";

const box = { left: 100, top: 50, width: 600, height: 300 };

test("drawing is true only while the drawing is on and the view shows a slide", () => {
  const deck = deckOf([2]);
  const on = { ...at(deck, 1, 1), draw: true };

  assert.equal(drawing(at(deck, 1, 1)), false);
  assert.equal(drawing(on), true);
  assert.equal(drawing({ ...on, view: "speaker" }), true);
  assert.equal(drawing({ ...on, view: "handout" }), false);
  assert.equal(drawing({ ...on, blank: true }), false);
  assert.equal(drawing({ ...on, overview: true }), false);
  assert.equal(drawing({ ...on, menu: true }), false);
  assert.equal(drawing({ ...on, help: true }), false);
});

test("tool returns the pen, or the highlighter while its field is true", () => {
  const state = at(deckOf([1]), 1, 1);

  assert.equal(tool(state), "pen");
  assert.equal(tool({ ...state, highlighter: true }), "highlighter");
});

test("start makes a line with one point, and extend adds a point", () => {
  const line = start("pen", { x: 0.25, y: 0.5 });
  assert.deepEqual(line, { tool: "pen", points: [[0.25, 0.5]] });

  const longer = extend(line, { x: 0.5, y: 0.5 });
  assert.deepEqual(longer, {
    tool: "pen",
    points: [
      [0.25, 0.5],
      [0.5, 0.5],
    ],
  });
  // The first line does not change.
  assert.equal(line.points.length, 1);
});

test("extend returns the same line for a place very near to the last point", () => {
  const line = start("highlighter", { x: 0.25, y: 0.5 });

  assert.equal(extend(line, { x: 0.25 + STEP / 2, y: 0.5 }), line);
  assert.notEqual(extend(line, { x: 0.25 + STEP * 2, y: 0.5 }), line);
});

test("nearest returns the place of a point, and an edge for a point outside the box", () => {
  assert.deepEqual(nearest(400, 200, box), { x: 0.5, y: 0.5 });
  assert.deepEqual(nearest(0, 0, box), { x: 0, y: 0 });
  assert.deepEqual(nearest(900, 200, box), { x: 1, y: 0.5 });
  assert.deepEqual(nearest(400, 900, box), { x: 0.5, y: 1 });
  assert.deepEqual(nearest(5, 5, { left: 0, top: 0, width: 0, height: 0 }), {
    x: 0,
    y: 0,
  });
});

test("path writes the points of a line with four decimal places at most", () => {
  const line = {
    tool: "pen" as const,
    points: [
      [0.2, 0.3],
      [0.123456, 0.5],
      [1, 0],
    ] as [number, number][],
  };

  assert.equal(path(line), "M0.2 0.3L0.1235 0.5L1 0");
});

test("path of a line with one point goes to that point again, and no point gives no path", () => {
  assert.equal(path(start("pen", { x: 0.5, y: 0.25 })), "M0.5 0.25L0.5 0.25");
  assert.equal(path({ tool: "pen", points: [] }), "");
});

test("message makes a message with the lines, and isDrawing takes it", () => {
  const lines = [start("pen", { x: 0, y: 1 })];

  assert.deepEqual(message(lines), { expresso: "drawing", lines });
  assert.ok(isDrawing(message(lines)));
  assert.ok(isDrawing(message([])));
  assert.ok(isDrawing({ ...message(lines), from: "an extension" }));
});

test("isDrawing refuses a wrong tool, a point outside the slide and each other value", () => {
  const line = (tool: string, points: unknown) => ({
    expresso: "drawing",
    lines: [{ tool, points }],
  });

  assert.equal(isDrawing(line("brush", [[0.5, 0.5]])), false);
  assert.equal(isDrawing(line("pen", [[1.5, 0.5]])), false);
  assert.equal(isDrawing(line("pen", [[0.5]])), false);
  assert.equal(isDrawing(line("pen", "M0 0")), false);
  assert.equal(isDrawing({ expresso: "drawing" }), false);
  assert.equal(isDrawing({ expresso: "pointer", lines: [] }), false);
  assert.equal(isDrawing(null), false);
});
