import { test } from "node:test";
import assert from "node:assert/strict";
import { apply, limits } from "../src/dom.ts";
import type { State, View } from "../src/state.ts";

// `dom.ts` reads the global `document` each time a function runs, so a fake
// document is enough to test it. Node has no DOM, and a browser is not
// necessary for these rules. The Playwright recipe of docs/development.md
// covers the parts that need a real browser, such as the CSS.

type FakeElement = {
  id: string;
  dataset: Record<string, string | undefined>;
  style: { display: string };
};

type FakeDocument = {
  body: { dataset: Record<string, string | undefined> };
  slides: FakeElement[];
  getElementsByClassName: (name: string) => FakeElement[];
  getElementById: (id: string) => FakeElement | null;
};

function fakeDocument(maxSteps: number[]): FakeDocument {
  const slides: FakeElement[] = maxSteps.map((max, index) => ({
    id: `slide-${index + 1}`,
    dataset: { maxStep: String(max) },
    style: { display: "none" },
  }));

  const doc: FakeDocument = {
    body: { dataset: {} },
    slides,
    getElementsByClassName: (name) => (name === "slide" ? slides : []),
    getElementById: (id) => slides.find((slide) => slide.id === id) ?? null,
  };

  (globalThis as unknown as { document: unknown }).document = doc;
  return doc;
}

// A state with no black screen and no digits.
function at(slide: number, step: number, view: View = "present"): State {
  return {
    slide,
    step,
    view,
    blank: false,
    digits: "",
    help: false,
    progress: true,
    every: false,
  };
}

test("limits reads the number of slides and the maximum step of each", () => {
  fakeDocument([1, 3, 2]);

  assert.deepEqual(limits(), { slides: 3, steps: [1, 3, 2] });
});

test("limits gives one step for a slide with no data-max-step", () => {
  const doc = fakeDocument([1, 1]);
  doc.slides[1].dataset.maxStep = undefined;

  assert.deepEqual(limits(), { slides: 2, steps: [1, 1] });
});

test("limits gives one step for a data-max-step that is not a number", () => {
  const doc = fakeDocument([1]);
  doc.slides[0].dataset.maxStep = "many";

  assert.deepEqual(limits(), { slides: 1, steps: [1] });
});

test("limits gives no slide for a document with no slide", () => {
  fakeDocument([]);

  assert.deepEqual(limits(), { slides: 0, steps: [] });
});

test("apply shows the slide of the state and hides each other slide", () => {
  const doc = fakeDocument([1, 3, 2]);

  apply(at(2, 3), limits());

  assert.deepEqual(
    doc.slides.map((slide) => slide.style.display),
    ["none", "flex", "none"],
  );
});

test("apply writes the step of the state on the slide of the state", () => {
  const doc = fakeDocument([1, 3]);

  apply(at(2, 3), limits());

  assert.equal(doc.slides[1].dataset.step, "3");
  assert.equal(doc.slides[0].dataset.step, undefined);
});

test("apply writes the view on the body", () => {
  const doc = fakeDocument([1]);

  apply(at(1, 1, "handout"), limits());
  assert.equal(doc.body.dataset.view, "handout");

  apply(at(1, 1), limits());
  assert.equal(doc.body.dataset.view, "present");
});

test("apply writes the view only for a document with no slide", () => {
  const doc = fakeDocument([]);

  apply(at(1, 1, "handout"), limits());

  assert.equal(doc.body.dataset.view, "handout");
});

test("apply throws for a slide that the document does not hold", () => {
  fakeDocument([1]);

  assert.throws(() => apply(at(2, 1), { slides: 1, steps: [1] }), {
    message: "The document has no slide 2",
  });
});

test("apply writes data-blank for a black screen, and removes it after", () => {
  const doc = fakeDocument([1]);

  apply({ ...at(1, 1), blank: true }, limits());
  assert.equal(doc.body.dataset.blank, "true");

  apply(at(1, 1), limits());
  assert.equal("blank" in doc.body.dataset, false);
});
