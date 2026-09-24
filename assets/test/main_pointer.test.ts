import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage } from "./page.ts";

// Two slides. Slide 1 has one step, and slide 2 has two steps. The window is
// 1200 pixels wide, so the left third ends at 400. The tests run in sequence
// on the same page.
const page = fakePage([1, 2]);
const { body } = page;

before(async () => {
  await import("../src/main.ts");
});

test("a click on the right two thirds goes to the next step", () => {
  page.click(900);
  assert.equal(page.location.hash, "#2.1");

  page.click(400);
  assert.equal(page.location.hash, "#2.2");
});

test("a click on the left third goes to the previous step", () => {
  page.click(399);
  assert.equal(page.location.hash, "#2.1");

  page.click(0);
  assert.equal(page.location.hash, "#1.1");
});

test("a click that the browser uses has no effect", () => {
  const count = page.written.length;
  page.click({ clientX: 900, button: 2 });
  for (const modifier of ["ctrlKey", "altKey", "metaKey", "shiftKey"]) {
    page.click({ clientX: 900, [modifier]: true });
  }
  page.click({ clientX: 900, inside: "a" });
  page.click({ clientX: 900, inside: "button" });

  page.selection = "a word";
  page.click(900);
  page.selection = "";

  assert.equal(page.written.length, count);
  assert.equal(page.location.hash, "#1.1");
});

test("a swipe to the left goes forward, and a swipe to the right goes back", () => {
  page.swipe({ x: 800, y: 300 }, { x: 600, y: 320 });
  assert.equal(page.location.hash, "#2.1");

  page.swipe({ x: 600, y: 300 }, { x: 800, y: 280 });
  assert.equal(page.location.hash, "#1.1");
});

test("a short or vertical movement of a finger has no effect", () => {
  const count = page.written.length;
  page.swipe({ x: 800, y: 300 }, { x: 760, y: 300 });
  page.swipe({ x: 800, y: 100 }, { x: 700, y: 400 });

  assert.equal(page.written.length, count);
});

test("a click closes a black screen, and it does nothing more", () => {
  page.press("b");
  assert.equal(body.dataset.blank, "true");

  page.click(900);
  assert.equal(body.dataset.blank, undefined);
  assert.equal(page.location.hash, "#1.1");
});

test("a swipe closes the list of keys, and it does nothing more", () => {
  page.press("?");
  assert.equal(body.dataset.help, "true");

  page.swipe({ x: 800, y: 300 }, { x: 600, y: 300 });
  assert.equal(body.dataset.help, undefined);
  assert.equal(page.location.hash, "#1.1");
});

test("f puts the document in full screen, and takes it out", () => {
  assert.equal(page.press("f"), true);
  assert.equal(page.fullscreen, true);

  assert.equal(page.press("f"), true);
  assert.equal(page.fullscreen, false);
});

test("f does nothing when the browser refuses full screen", () => {
  page.refuses = true;
  assert.equal(page.press("f"), true);
  assert.equal(page.fullscreen, false);
  page.refuses = false;
});

test("f on the list of keys closes the list, and it does nothing more", () => {
  page.press("?");
  page.press("f");

  assert.equal(body.dataset.help, undefined);
  assert.equal(page.fullscreen, false);
});

test("the handout view ignores clicks, swipes and f", () => {
  page.press("p");
  assert.equal(body.dataset.view, "handout");
  const count = page.written.length;

  page.click(900);
  page.click(0);
  page.swipe({ x: 800, y: 300 }, { x: 600, y: 300 });
  assert.equal(page.press("f"), false);

  assert.equal(page.written.length, count);
  assert.equal(page.fullscreen, false);
});

test("a click in the handout view closes the list of keys", () => {
  page.press("?");
  assert.equal(body.dataset.help, "true");

  page.click(900);
  assert.equal(body.dataset.help, undefined);
  assert.equal(body.dataset.view, "handout");
});
