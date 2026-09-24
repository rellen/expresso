import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage, last } from "./page.ts";

// Two slides. Slide 1 has one step, and slide 2 has two steps. The address has
// no fragment, and the tests run in sequence on the same page.
const page = fakePage([1, 2]);
const { slides, body } = page;

before(async () => {
  await import("../src/main.ts");
});

function displays(): string[] {
  return slides.map((slide) => slide.style.display);
}

test("an address with no fragment shows step 1, and writes no fragment", () => {
  assert.equal(body.dataset.view, "present");
  assert.equal(slides[0].dataset.step, "1");
  assert.deepEqual(page.written, []);
});

test("the progress bar is on and empty at load", () => {
  assert.equal(body.dataset.progress, "true");
  assert.equal(page.element("progress")?.style.width, "0%");
});

test("an unknown key writes nothing, because the state does not change", () => {
  const count = page.written.length;
  assert.equal(page.press("x"), false);

  assert.equal(page.written.length, count);
  assert.deepEqual(displays(), ["flex", "none"]);
});

test("j moves to the next slide after the last step of the first slide", () => {
  assert.equal(page.press("j"), true);

  assert.deepEqual(displays(), ["none", "flex"]);
  assert.equal(slides[1].dataset.step, "1");
  assert.equal(page.location.hash, "#2.1");
});

test("j moves to the next step inside the slide", () => {
  page.press("j");

  assert.equal(slides[1].dataset.step, "2");
  assert.equal(page.location.hash, "#2.2");
});

test("j on the last step of the last slide writes nothing new", () => {
  const count = page.written.length;

  assert.equal(page.press("j"), false);
  assert.equal(slides[1].dataset.step, "2");
  assert.equal(page.written.length, count);
});

test("k moves back through the steps and the slides", () => {
  page.press("k");
  assert.equal(slides[1].dataset.step, "1");

  page.press("k");
  assert.equal(slides[0].dataset.step, "1");
  assert.deepEqual(displays(), ["flex", "none"]);
  assert.equal(page.location.hash, "#1.1");
});

test("a key with Control, Alt or Meta goes to the browser", () => {
  for (const modifier of ["ctrlKey", "altKey", "metaKey"]) {
    assert.equal(page.press({ key: "j", [modifier]: true }), false, modifier);
  }
  assert.deepEqual(displays(), ["flex", "none"]);
});

test("the space bar and End move, and the browser does not scroll", () => {
  assert.equal(page.press(" "), true);
  assert.deepEqual(displays(), ["none", "flex"]);

  page.press("Home");
  assert.equal(page.press("End"), true);
  assert.equal(page.location.hash, "#2.1");
});

test("digits and Enter go to a slide", () => {
  page.press("1");
  page.press("Enter");

  assert.deepEqual(displays(), ["flex", "none"]);
});

test("b writes data-blank, and the next key removes it", () => {
  page.press("b");
  assert.equal(body.dataset.blank, "true");

  page.press("j");
  assert.equal("blank" in body.dataset, false);
  assert.deepEqual(displays(), ["flex", "none"]);
});

test("a new fragment in the address moves to that step", () => {
  page.navigate("#2.2");

  assert.deepEqual(displays(), ["none", "flex"]);
  assert.equal(slides[1].dataset.step, "2");
});

test("p changes the view, and p again changes it back", () => {
  page.press("p");
  assert.equal(body.dataset.view, "handout");

  assert.equal(page.press("ArrowDown"), false);
  assert.equal(page.press(" "), false);

  page.press("p");
  assert.equal(body.dataset.view, "present");
});

test("s opens the speaker view at the current step, and a second s opens no second window", () => {
  page.navigate("#2.1");
  assert.equal(page.press("s"), true);

  assert.equal(page.opened.length, 1);
  assert.equal(page.opened[0].url, "file:///deck.html?speaker=#2.1");
  assert.equal(page.opened[0].name, "expresso-speaker");
});

test("each change goes to the speaker view", () => {
  const speaker = page.opened[0].window;
  page.press("k");

  assert.deepEqual(last(speaker), {
    expresso: "position",
    slide: 1,
    step: 1,
    blank: false,
  });
});

test("a message from the speaker view moves the present view", () => {
  page.receive(
    { expresso: "position", slide: 2, step: 2, blank: true },
    page.opened[0].window,
  );

  assert.deepEqual(displays(), ["none", "flex"]);
  assert.equal(slides[1].dataset.step, "2");
  assert.equal(body.dataset.blank, "true");
});

test("a message from another window has no effect", () => {
  page.press("x");
  page.receive({ expresso: "position", slide: 1, step: 1, blank: false }, null);

  assert.equal(slides[1].dataset.step, "2");
  assert.deepEqual(displays(), ["none", "flex"]);
});

test("? shows the list of keys of the present view, and the next key closes it", () => {
  const before = displays();
  assert.equal(page.press("?"), true);

  assert.equal(body.dataset.help, "true");
  const panel = page.element("help");
  assert.ok(panel, "no element help");
  const names = panel.children.map((row) => row.children[0].textContent);
  assert.ok(names.includes("s"));
  assert.ok(names.includes("?"));

  page.press("j");
  assert.equal("help" in body.dataset, false);
  assert.deepEqual(displays(), before);
});

test("s on the list of keys closes it, and opens no window", () => {
  const count = page.opened.length;
  page.press("?");
  page.press("s");

  assert.equal("help" in body.dataset, false);
  assert.equal(page.opened.length, count);
});

test("the progress bar follows the step, and g hides and shows it", () => {
  page.navigate("#2.1");
  assert.equal(page.element("progress")?.style.width, "50%");

  assert.equal(page.press("g"), true);
  assert.equal(body.dataset.progress, "false");
  page.press("g");
  assert.equal(body.dataset.progress, "true");
});
