import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage, fakeWindow, last, SPEAKER_BOX } from "./page.ts";
import { position } from "./messages.ts";

// The speaker view of a deck with two slides. Slide 1 has two steps. The
// present view opened this window, so each message of the zoom goes to it.
// The page of the current step is at `SPEAKER_BOX`. The tests run in
// sequence on the same page.
const opener = fakeWindow();
const page = fakePage([2, 1], { search: "?speaker", hash: "#1.1", opener });

before(async () => {
  await import("../src/main.ts");
});

// The zoom that the `html` element holds, or null for the full slide. The
// custom properties stay after a zoom, so `data-zoomed` tells if it shows.
function zoom(): Record<string, string | undefined> | null {
  const root = page.document.documentElement;
  const { properties } = root.style;
  return root.dataset.zoomed === undefined
    ? null
    : {
        scale: properties["--zoom-scale"],
        x: properties["--zoom-x"],
        y: properties["--zoom-y"],
      };
}

// A point of the page of the current step, from a part of its width and of
// its height.
function on(x: number, y: number): { clientX: number; clientY: number } {
  return {
    clientX: SPEAKER_BOX.left + x * SPEAKER_BOX.width,
    clientY: SPEAKER_BOX.top + y * SPEAKER_BOX.height,
  };
}

// The box of an element that starts at one fifth of the slide and takes two
// fifths of it in each direction.
const box = {
  left: SPEAKER_BOX.left + 0.2 * SPEAKER_BOX.width,
  top: SPEAKER_BOX.top + 0.2 * SPEAKER_BOX.height,
  width: 0.4 * SPEAKER_BOX.width,
  height: 0.4 * SPEAKER_BOX.height,
};

// The area of the last message of the zoom, with no more than four digits
// after the point in each value.
function sent(): Record<string, number> | null {
  const message = last(opener) as {
    expresso: string;
    area: Record<string, number> | null;
  };
  assert.equal(message.expresso, "zoom");
  return message.area === null
    ? null
    : Object.fromEntries(
        Object.entries(message.area).map(([key, value]) => [
          key,
          Math.round(value * 1e4) / 1e4,
        ]),
      );
}

test("a click with no key changes the step, and it does not zoom", () => {
  page.click({ ...on(0.9, 0.5), box });

  assert.equal(zoom(), null);
  assert.equal(page.location.hash, "#1.2");
  page.press("k");
  assert.equal(page.location.hash, "#1.1");
});

test("a click with the Alt key zooms to the element under the mouse, in the two windows", () => {
  const stopped = page.click({ ...on(0.3, 0.3), altKey: true, box });

  assert.equal(stopped, true);
  assert.deepEqual(zoom(), { scale: "2.2727", x: "-0.4091", y: "-0.4091" });
  assert.deepEqual(sent(), { x: 0.18, y: 0.18, width: 0.44, height: 0.44 });
  assert.equal(page.location.hash, "#1.1");
});

test("the next click with the Alt key shows the full slide, in the two windows", () => {
  page.click({ ...on(0.3, 0.3), altKey: true, box });

  assert.equal(zoom(), null);
  assert.equal(sent(), null);
});

test("a click with the Alt key outside each element zooms by 2 around the point", () => {
  page.click({ ...on(0.5, 0.5), altKey: true });

  assert.deepEqual(zoom(), { scale: "2", x: "-0.5", y: "-0.5" });
  assert.deepEqual(sent(), { x: 0.25, y: 0.25, width: 0.5, height: 0.5 });
});

test("Escape shows the full slide, in the two windows", () => {
  const stopped = page.press("Escape");

  assert.equal(stopped, true);
  assert.equal(zoom(), null);
  assert.equal(sent(), null);
});

test("a click with the Alt key outside the slide does nothing", () => {
  const messages = opener.received.length;
  const stopped = page.click({
    clientX: SPEAKER_BOX.left - 10,
    clientY: SPEAKER_BOX.top + 10,
    altKey: true,
    box,
  });

  assert.equal(stopped, false);
  assert.equal(zoom(), null);
  assert.equal(opener.received.length, messages);
  assert.equal(page.location.hash, "#1.1");
});

test("a click with the Alt key and a second modifier goes to the browser", () => {
  const messages = opener.received.length;
  page.click({ ...on(0.3, 0.3), altKey: true, shiftKey: true, box });
  page.click({ ...on(0.3, 0.3), altKey: true, button: 1, box });

  assert.equal(zoom(), null);
  assert.equal(opener.received.length, messages);
});

test("a change of the step shows the full slide, with no message of the zoom", () => {
  page.click({ ...on(0.3, 0.3), altKey: true, box });
  assert.notEqual(zoom(), null);

  page.press("j");

  assert.equal(page.location.hash, "#1.2");
  assert.equal(zoom(), null);
  assert.equal((last(opener) as { expresso: string }).expresso, "position");
});

test("z turns the zoom on in the two windows, and a click then zooms", () => {
  page.press("z");

  assert.equal(page.body.dataset.zoom, "true");
  assert.equal(
    (last(opener) as { fields: { zoom: boolean } }).fields.zoom,
    true,
  );
  assert.equal(zoom(), null);

  const stopped = page.click({ ...on(0.3, 0.3), box });

  assert.equal(stopped, true);
  assert.deepEqual(zoom(), { scale: "2.2727", x: "-0.4091", y: "-0.4091" });
  assert.equal(page.location.hash, "#1.2");
});

test("the next click shows the full slide while the zoom is on", () => {
  page.click({ ...on(0.8, 0.8) });

  assert.equal(zoom(), null);
  assert.equal(sent(), null);
  assert.equal(page.location.hash, "#1.2");
});

test("a swipe does not change the step while the zoom is on", () => {
  page.swipe({ x: 500, y: 100 }, { x: 100, y: 100 });

  assert.equal(page.location.hash, "#1.2");
});

test("a second z turns the zoom off and shows the full slide", () => {
  page.click({ ...on(0.3, 0.3), box });
  assert.notEqual(zoom(), null);

  page.press("z");

  assert.equal(page.body.dataset.zoom, undefined);
  assert.equal(zoom(), null);
  assert.equal(
    (last(opener) as { fields: { zoom: boolean } }).fields.zoom,
    false,
  );
});

test("Escape turns the zoom off", () => {
  page.press("z");
  page.click({ ...on(0.3, 0.3), box });
  page.press("Escape");

  assert.equal(page.body.dataset.zoom, undefined);
  assert.equal(zoom(), null);
});

test("a message of the other window zooms this window, and sends no message", () => {
  const messages = opener.received.length;
  const area = { x: 0.5, y: 0, width: 0.5, height: 0.5 };
  page.receive({ expresso: "zoom", area }, opener);

  assert.deepEqual(zoom(), { scale: "2", x: "-1", y: "0" });
  assert.equal(opener.received.length, messages);

  page.receive({ expresso: "zoom", area: null }, opener);
  assert.equal(zoom(), null);
  assert.equal(opener.received.length, messages);
});

test("a message of the zoom from a different window has no effect", () => {
  const area = { x: 0.5, y: 0, width: 0.5, height: 0.5 };
  page.receive({ expresso: "zoom", area }, fakeWindow());

  assert.equal(zoom(), null);
});

test("a move of the other window to a different step shows the full slide", () => {
  page.click({ ...on(0.5, 0.5), altKey: true });
  assert.notEqual(zoom(), null);

  // The clock of the test can give the same time to two messages, so the
  // time of this message is after each time of this window.
  page.receive(position({ step: 1, time: Date.now() + 60_000 }), opener);

  assert.equal(page.location.hash, "#1.1");
  assert.equal(zoom(), null);
});

test("z turns the laser pointer and the drawing off, and each of them turns the zoom off", () => {
  page.press("l");
  page.press("z");
  assert.equal(page.body.dataset.zoom, "true");
  assert.equal(page.body.dataset.laser, undefined);

  page.press("x");
  assert.equal(page.body.dataset.draw, "true");
  assert.equal(page.body.dataset.zoom, undefined);

  page.press("z");
  assert.equal(page.body.dataset.draw, undefined);
  page.press("l");
  assert.equal(page.body.dataset.zoom, undefined);
  page.press("l");
});

test("the overview shows no zoom, and a click with the Alt key does nothing there", () => {
  page.press("o");
  const messages = opener.received.length;
  page.click({ ...on(0.3, 0.3), altKey: true, box });

  assert.equal(zoom(), null);
  assert.equal(opener.received.length, messages);
  page.press("o");
});

test("the list of keys shows the keys of the zoom", () => {
  page.press("?");
  const names = page.keys().map((each) => each.names);

  for (const key of ["z", "Esc"]) {
    assert.ok(names.includes(key), `the list has no key ${key}`);
  }
});
