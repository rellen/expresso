import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage, fakeWindow, last, SPEAKER_BOX } from "./page.ts";
import { position } from "./messages.ts";

// The speaker view of a deck with two slides. Slide 1 has two steps. The
// present view opened this window, so each message of the drawing goes to
// it. The page of the current step is at `SPEAKER_BOX`. The tests run in
// sequence on the same page.
const opener = fakeWindow();
const page = fakePage([2, 1], { search: "?speaker", hash: "#1.1", opener });

before(async () => {
  await import("../src/main.ts");
});

// The class and the path of each line that the layer of the drawing holds.
function paths(): [string | undefined, string | undefined][] {
  const layer = page.element("drawing");
  assert.ok(layer, "the fake page has no layer of the drawing");
  return layer.children.map((each) => [
    each.attributes["class"],
    each.attributes["d"],
  ]);
}

// A point of the page of the current step, from a part of its width and of
// its height.
function on(x: number, y: number): { x: number; y: number } {
  return {
    x: SPEAKER_BOX.left + x * SPEAKER_BOX.width,
    y: SPEAKER_BOX.top + y * SPEAKER_BOX.height,
  };
}

// The lines of the last message of the drawing that the other window got.
function sent(): unknown {
  const message = last(opener) as { expresso: string; lines: unknown };
  assert.equal(message.expresso, "drawing");
  return message.lines;
}

test("a drag draws no line while the drawing is off", () => {
  const messages = opener.received.length;
  page.drag([on(0.2, 0.2), on(0.4, 0.2)]);

  assert.deepEqual(paths(), []);
  assert.equal(opener.received.length, messages);
});

test("x turns the drawing on in the two windows", () => {
  page.press("x");

  assert.equal(page.body.dataset.draw, "true");
  assert.equal(
    (last(opener) as { fields: { draw: boolean } }).fields.draw,
    true,
  );
});

test("a drag draws a line with the pen, and sends it as parts of the slide", () => {
  page.drag([on(0.25, 0.5), on(0.5, 0.5), on(0.5, 0.75)]);

  assert.deepEqual(paths(), [["drawing-pen", "M0.25 0.5L0.5 0.5L0.5 0.75"]]);
  assert.deepEqual(sent(), [
    {
      tool: "pen",
      points: [
        [0.25, 0.5],
        [0.5, 0.5],
        [0.5, 0.75],
      ],
    },
  ]);
});

test("the layer of the drawing is on the box of the slide, with its scale", () => {
  const layer = page.element("drawing");
  assert.ok(layer);

  assert.equal(layer.style.left, `${SPEAKER_BOX.left}px`);
  assert.equal(layer.style.top, `${SPEAKER_BOX.top}px`);
  assert.equal(layer.style.width, `${SPEAKER_BOX.width}px`);
  assert.equal(layer.style.height, `${SPEAKER_BOX.height}px`);
  // The window of the fake page is 1200 pixels wide.
  assert.equal(layer.style.properties["--draw-scale"], "0.5");
});

test("a drag past an edge of the slide continues along that edge", () => {
  page.drag([
    on(0.9, 0.1),
    { x: SPEAKER_BOX.left + SPEAKER_BOX.width + 50, y: 0 },
  ]);

  assert.deepEqual(paths()[1], ["drawing-pen", "M0.9 0.1L1 0"]);
});

test("a drag that starts outside the slide draws no line", () => {
  page.drag([
    { x: SPEAKER_BOX.left - 20, y: SPEAKER_BOX.top + 20 },
    on(0.5, 0.5),
  ]);

  assert.equal(paths().length, 2);
});

test("a click and a swipe do not change the step while the drawing is on", () => {
  page.click(1000);
  page.swipe({ x: 500, y: 100 }, { x: 100, y: 100 });

  assert.equal(page.location.hash, "#1.1");
});

test("h changes the tool to the highlighter for the next line", () => {
  page.press("h");
  page.drag([on(0.1, 0.9), on(0.6, 0.9)]);

  assert.equal(page.body.dataset.highlighter, "true");
  assert.deepEqual(paths()[2], ["drawing-highlighter", "M0.1 0.9L0.6 0.9"]);
  assert.deepEqual(paths()[0]?.[0], "drawing-pen");
});

test("a click with no move draws a dot", () => {
  page.drag([on(0.5, 0.5)]);

  assert.deepEqual(paths()[3], ["drawing-highlighter", "M0.5 0.5L0.5 0.5"]);
});

test("the next step of the slide keeps the drawing", () => {
  page.press("j");

  assert.equal(page.location.hash, "#1.2");
  assert.equal(paths().length, 4);
  assert.equal(page.body.dataset.draw, "true");
});

test("c removes the drawing in the two windows", () => {
  page.press("c");

  assert.deepEqual(paths(), []);
  assert.deepEqual(sent(), []);
});

test("a message of the other window replaces the drawing", () => {
  const lines = [
    {
      tool: "pen",
      points: [
        [0, 0],
        [1, 1],
      ],
    },
  ];
  page.receive({ expresso: "drawing", lines }, opener);

  assert.deepEqual(paths(), [["drawing-pen", "M0 0L1 1"]]);

  page.receive(
    { expresso: "drawing", lines: [{ tool: "brush", points: [] }] },
    opener,
  );
  page.receive({ expresso: "drawing", lines: [] }, fakeWindow());
  assert.equal(paths().length, 1);
});

test("a change of the slide removes the drawing", () => {
  page.press("j");

  assert.equal(page.location.hash, "#2.1");
  assert.deepEqual(paths(), []);
});

test("l turns the drawing off, and x turns the laser pointer off", () => {
  assert.equal(page.body.dataset.draw, "true");

  page.press("l");
  assert.equal(page.body.dataset.draw, undefined);
  assert.equal(page.body.dataset.laser, "true");

  page.press("x");
  assert.equal(page.body.dataset.draw, "true");
  assert.equal(page.body.dataset.laser, undefined);
});

test("a second x turns the drawing off, and a click then changes the step", () => {
  // The clock of the test can give the same time to two messages, so the
  // time of this message is after each time of this window.
  page.receive(
    position({ step: 1, draw: true, time: Date.now() + 60_000 }),
    opener,
  );
  page.press("x");

  assert.equal(page.body.dataset.draw, undefined);
  page.click(1000);
  assert.equal(page.location.hash, "#1.2");
});

test("the list of keys shows the keys of the drawing", () => {
  page.press("?");
  const names = page.keys().map((each) => each.names);

  for (const key of ["x", "h", "c"]) {
    assert.ok(names.includes(key), `the list has no key ${key}`);
  }
});
