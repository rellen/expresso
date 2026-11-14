import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage, fakeWindow, last, SCREEN_BOX, SPEAKER_BOX } from "./page.ts";
import { position } from "./messages.ts";

// The speaker view of a deck with two slides. Slide 1 has two steps. The
// present view opened this window, so each message of the pointer goes to
// it. The page of the current step is at `SPEAKER_BOX`. The tests run in
// sequence on the same page.
const opener = fakeWindow();
const page = fakePage([2, 1], { search: "?speaker", hash: "#1.1", opener });

before(async () => {
  await import("../src/main.ts");
});

// The place of the dot in the window, or null while the dot does not show.
function dot(): { left: string | undefined; top: string | undefined } | null {
  const laser = page.element("laser");
  assert.ok(laser, "the fake page has no dot");
  return laser.dataset.shown === undefined
    ? null
    : { left: laser.style.left, top: laser.style.top };
}

// A point of the page of the current step, from a part of its width and of
// its height.
function on(x: number, y: number): { x: number; y: number } {
  return {
    x: SPEAKER_BOX.left + x * SPEAKER_BOX.width,
    y: SPEAKER_BOX.top + y * SPEAKER_BOX.height,
  };
}

test("a move of the mouse shows no dot while the pointer is off", () => {
  const messages = opener.received.length;
  page.point(on(0.5, 0.5));

  assert.equal(page.body.dataset.laser, undefined);
  assert.equal(dot(), null);
  assert.equal(opener.received.length, messages);
});

test("l turns the pointer on in the two windows, and shows no dot before a move", () => {
  page.press("l");

  assert.equal(page.body.dataset.laser, "true");
  assert.equal(dot(), null);
  assert.equal(
    (last(opener) as { fields: { laser: boolean } }).fields.laser,
    true,
  );
});

test("a move of the mouse puts the dot at the mouse, and sends the part of the slide", () => {
  page.point(on(0.25, 0.5));

  assert.deepEqual(dot(), { left: "250px", top: "200px" });
  assert.deepEqual(last(opener), { expresso: "pointer", x: 0.25, y: 0.5 });
});

test("a move outside the slide hides the dot in the two windows", () => {
  page.point({ x: SPEAKER_BOX.left - 10, y: SPEAKER_BOX.top + 10 });

  assert.equal(dot(), null);
  assert.deepEqual(last(opener), { expresso: "pointer", x: null, y: null });
});

test("a click does not change the step while the pointer is on", () => {
  page.point(on(0.75, 0.5));
  const written = page.written.length;
  page.click(1000);

  assert.equal(page.written.length, written);
  assert.equal(page.location.hash, "#1.1");
  assert.deepEqual(dot(), { left: "550px", top: "200px" });
});

test("a swipe does not change the step while the pointer is on", () => {
  page.swipe({ x: 500, y: 100 }, { x: 100, y: 100 });

  assert.equal(page.location.hash, "#1.1");
});

test("the mouse that leaves the window hides the dot in the two windows", () => {
  page.point(null);

  assert.equal(dot(), null);
  assert.deepEqual(last(opener), { expresso: "pointer", x: null, y: null });
});

test("a message of the other window puts the dot on the same part of the slide", () => {
  page.receive({ expresso: "pointer", x: 0.5, y: 1 }, opener);

  assert.deepEqual(dot(), { left: "400px", top: "350px" });

  page.receive({ expresso: "pointer", x: null, y: null }, opener);
  assert.equal(dot(), null);
});

test("a message with a place outside the slide, or from a different window, moves no dot", () => {
  page.receive({ expresso: "pointer", x: 2, y: 0.5 }, opener);
  assert.equal(dot(), null);

  page.receive({ expresso: "pointer", x: 0.5, y: 0.5 }, fakeWindow());
  assert.equal(dot(), null);
});

test("the next step turns the pointer off, and the dot goes away", () => {
  page.point(on(0.5, 0.5));
  assert.notEqual(dot(), null);

  page.press("j");

  assert.equal(page.location.hash, "#1.2");
  assert.equal(page.body.dataset.laser, undefined);
  assert.equal(dot(), null);
  assert.equal(
    (last(opener) as { fields: { laser: boolean } }).fields.laser,
    false,
  );
});

test("the pointer of the other window turns on with its message, and a click then moves no step", () => {
  // The clock of the test can give the same time to two messages, so the
  // time of this message is after each time of this window.
  const time = Date.now() + 60_000;
  page.receive(position({ step: 2, laser: true, time }), opener);

  assert.equal(page.body.dataset.laser, "true");

  page.receive({ expresso: "pointer", x: 0, y: 0 }, opener);
  assert.deepEqual(dot(), {
    left: `${SPEAKER_BOX.left}px`,
    top: `${SPEAKER_BOX.top}px`,
  });

  page.click(1000);
  assert.equal(page.location.hash, "#1.2");
});

test("the list of keys shows the key of the pointer", () => {
  page.press("l");
  page.press("?");

  const row = page.keys().find((each) => each.names === "l");
  assert.ok(
    row?.text.startsWith("Laser pointer on or off, in the two windows."),
  );
  assert.deepEqual(SCREEN_BOX.width, 1200);
});
