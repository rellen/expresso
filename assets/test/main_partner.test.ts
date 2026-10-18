import { test, before, mock } from "node:test";
import assert from "node:assert/strict";
import { fakePage, fakeWindow, last, lastPosition } from "./page.ts";
import { nth } from "./nth.ts";
import { position } from "./messages.ts";

// The present view of three slides of one step each, with no speaker view at
// the start. The tests run in sequence on the same page.
const page = fakePage([1, 1, 1], { hash: "#2.1" });
const { body } = page;

mock.timers.enable({ apis: ["Date"], now: 1_000_000 });

before(async () => {
  await import("../src/main.ts");
});

// A window that this window did not open, such as the page of an embed. It
// has no opener.
const frame = fakeWindow();

test("a message from a frame of the document has no effect", () => {
  page.receive(position({ slide: 3, blank: true, time: 1e15 }), frame);

  assert.equal(page.location.hash, "#2.1");
  assert.equal(body.dataset.blank, undefined);
  assert.deepEqual(frame.received, []);
});

test("a request from a frame of the document gets no answer", () => {
  page.receive({ expresso: "request" }, frame);

  assert.deepEqual(frame.received, []);
});

test("the speaker view asks for the state, and the present view answers with its full state", () => {
  page.press("s");
  const speaker = nth(page.opened, 0).window;
  page.receive({ expresso: "request" }, speaker);

  assert.deepEqual(lastPosition(speaker), position({ slide: 2 }));
});

test("a message with a very large time does not stop the next messages", () => {
  const speaker = nth(page.opened, 0).window;
  page.receive(position({ slide: 3, time: 1e15 }), speaker);
  assert.equal(page.location.hash, "#3.1");

  mock.timers.tick(2_000);
  page.receive(position({ slide: 1, time: Date.now() + 5_000 }), speaker);
  assert.equal(page.location.hash, "#1.1");
});

test("a second s shows the open speaker view again, and does not load it again", () => {
  const speaker = nth(page.opened, 0).window;
  const count = speaker.received.length;
  page.press("s");

  assert.equal(page.opened.length, 1);
  assert.equal(speaker.focused, 1);
  assert.equal(speaker.received.length, count);
});

test("a closed speaker view opens again at the next s", () => {
  nth(page.opened, 0).window.closed = true;
  page.press("s");

  assert.equal(page.opened.length, 2);
  assert.equal(nth(page.opened, 1).url, "file:///deck.html?speaker=#1.1");
});

test("a key on an element inside the list of keys goes to the browser", () => {
  page.press("?");
  const summary = {
    closest: (selector: string) => (selector === "#help" ? summary : null),
  };
  for (const key of ["Tab", "Enter", " "]) {
    assert.equal(page.press({ key, target: summary }), false);
    assert.equal(body.dataset.help, "true");
  }
  assert.equal(last(nth(page.opened, 1).window), undefined);
});
