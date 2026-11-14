import { test } from "node:test";
import assert from "node:assert/strict";
import {
  around,
  areaOf,
  FACTOR,
  isZoom,
  LIMIT,
  MARGIN,
  message,
  scaleOf,
  target,
  zoomable,
  zooming,
} from "../src/zoom.ts";
import type { State } from "../src/state.ts";

const state: State = {
  index: 0,
  view: "present",
  blank: false,
  white: false,
  digits: "",
  help: false,
  progress: true,
  every: false,
  overview: false,
  selected: 1,
  undim: false,
  menu: false,
  cursor: 0,
  laser: false,
  draw: false,
  highlighter: false,
  zoom: false,
  paused: false,
};

// The box of a slide of 1000 by 500 pixels at the point 100, 50.
const slide = { left: 100, top: 50, width: 1000, height: 500 };

// The values of an area, each with no more than six digits after the point.
function near(area: Record<string, number>): Record<string, number> {
  return Object.fromEntries(
    Object.entries(area).map(([key, value]) => [
      key,
      Math.round(value * 1e6) / 1e6,
    ]),
  );
}

test("zoomable is true in the present view and in the speaker view with no cover", () => {
  assert.equal(zoomable(state), true);
  assert.equal(zoomable({ ...state, view: "speaker" }), true);
  assert.equal(zoomable({ ...state, view: "handout" }), false);
  assert.equal(zoomable({ ...state, blank: true }), false);
  assert.equal(zoomable({ ...state, overview: true }), false);
  assert.equal(zoomable({ ...state, menu: true }), false);
  assert.equal(zoomable({ ...state, help: true }), false);
});

test("zooming is true only while the field zoom is true and the window shows a slide", () => {
  assert.equal(zooming(state), false);
  assert.equal(zooming({ ...state, zoom: true }), true);
  assert.equal(zooming({ ...state, zoom: true, overview: true }), false);
  assert.equal(zooming({ ...state, zoom: true, view: "handout" }), false);
});

test("around returns the area of the factor around a place", () => {
  assert.equal(FACTOR, 2);
  assert.deepEqual(around({ x: 0.5, y: 0.5 }), {
    x: 0.25,
    y: 0.25,
    width: 0.5,
    height: 0.5,
  });
});

test("around keeps the area on the slide near an edge", () => {
  assert.deepEqual(around({ x: 0.1, y: 0.95 }), {
    x: 0,
    y: 0.5,
    width: 0.5,
    height: 0.5,
  });
});

test("areaOf returns the box of an element as a part of the slide, with the margin", () => {
  assert.equal(MARGIN, 0.02);
  const element = { left: 300, top: 150, width: 400, height: 200 };

  assert.deepEqual(near(areaOf(element, slide)!), {
    x: 0.18,
    y: 0.18,
    width: 0.44,
    height: 0.44,
  });
});

test("areaOf keeps the margin of an element at an edge on the slide", () => {
  const element = { left: 100, top: 300, width: 300, height: 250 };

  assert.deepEqual(near(areaOf(element, slide)!), {
    x: 0,
    y: 0.48,
    width: 0.32,
    height: 0.52,
  });
});

test("areaOf returns null for an element that fills most of the slide", () => {
  const wide = { left: 150, top: 200, width: 900, height: 100 };
  const full = { left: 100, top: 50, width: 1000, height: 500 };

  assert.equal(areaOf(wide, slide), null);
  assert.equal(areaOf(full, slide), null);
});

test("areaOf returns null for a slide or an element with no size", () => {
  const element = { left: 300, top: 150, width: 400, height: 200 };

  assert.equal(areaOf(element, { ...slide, width: 0 }), null);
  assert.equal(areaOf({ ...element, left: 2000 }, slide), null);
});

test("target returns the area of the element, or the area around the place", () => {
  const element = { left: 300, top: 150, width: 400, height: 200 };
  const wide = { left: 150, top: 200, width: 900, height: 100 };
  const place = { x: 0.5, y: 0.5 };

  assert.deepEqual(target(place, element, slide), areaOf(element, slide));
  assert.deepEqual(target(place, wide, slide), around(place));
  assert.deepEqual(target(place, null, slide), around(place));
});

test("scaleOf puts the center of the area at the center of the slide", () => {
  assert.deepEqual(scaleOf({ x: 0.25, y: 0.25, width: 0.5, height: 0.5 }), {
    scale: 2,
    x: -0.5,
    y: -0.5,
  });
});

test("scaleOf takes the smaller scale of the two directions", () => {
  const scale = scaleOf({ x: 0.3, y: 0.4, width: 0.4, height: 0.2 });

  assert.deepEqual(near(scale), { scale: 2.5, x: -0.75, y: -0.75 });
});

test("scaleOf keeps each edge of the slide at an edge of the window or outside it", () => {
  assert.deepEqual(scaleOf({ x: 0, y: 0.5, width: 0.5, height: 0.5 }), {
    scale: 2,
    x: 0,
    y: -1,
  });
  // The center of this area is near the top left corner, so the slide
  // cannot move to it.
  assert.deepEqual(scaleOf({ x: 0, y: 0, width: 0.4, height: 0.5 }), {
    scale: 2,
    x: 0,
    y: 0,
  });
});

test("scaleOf gives a scale from 1 to the limit", () => {
  assert.equal(LIMIT, 4);
  assert.equal(scaleOf({ x: 0.45, y: 0.45, width: 0.1, height: 0.1 }).scale, 4);
  assert.equal(scaleOf({ x: 0.5, y: 0.5, width: 0, height: 0 }).scale, 4);
  assert.deepEqual(scaleOf({ x: 0, y: 0, width: 1, height: 1 }), {
    scale: 1,
    x: 0,
    y: 0,
  });
});

test("message returns the message of an area, and of the full slide", () => {
  const area = { x: 0.25, y: 0.25, width: 0.5, height: 0.5 };

  assert.deepEqual(message(area), { expresso: "zoom", area });
  assert.deepEqual(message(null), { expresso: "zoom", area: null });
});

test("isZoom takes a message of the zoom, and refuses each other value", () => {
  const area = { x: 0.25, y: 0.25, width: 0.5, height: 0.5 };

  assert.equal(isZoom(message(area)), true);
  assert.equal(isZoom(message(null)), true);
  assert.equal(isZoom({ expresso: "zoom", area, other: 1 }), true);
  assert.equal(isZoom({ expresso: "zoom" }), false);
  assert.equal(isZoom({ expresso: "zoom", area: { ...area, x: 2 } }), false);
  assert.equal(isZoom({ expresso: "zoom", area: { x: 0, y: 0 } }), false);
  assert.equal(isZoom({ expresso: "pointer", x: 0, y: 0 }), false);
  assert.equal(isZoom(null), false);
});
