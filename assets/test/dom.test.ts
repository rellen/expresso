import { test } from "node:test";
import assert from "node:assert/strict";
import { apply, deck } from "../src/dom.ts";
import type { Deck } from "../src/deck.ts";
import type { State, View } from "../src/state.ts";
import { at as atIn, deckOf, json } from "./decks.ts";
import { load } from "./fixtures.ts";
import { nth } from "./nth.ts";
import { fakeBody } from "./page.ts";
import type { FakeBody } from "./page.ts";

// The projections do not depend on the deck, so each test uses the program of
// one deck of the fixture file.
const program = load("1,2").program;

// `dom.ts` reads the global `document` each time a function runs, so a fake
// document is enough to test it. Node has no DOM, and a browser is not
// necessary for these rules. The Playwright recipe of docs/development.md
// covers the parts that need a real browser, such as the CSS.

type FakeElement = {
  id: string;
  dataset: Record<string, string | undefined>;
  style: { display: string };
  textContent?: string;
};

type FakeDocument = {
  body: FakeBody;
  slides: FakeElement[];
  list: FakeElement;
  getElementsByClassName: (name: string) => FakeElement[];
  getElementById: (id: string) => FakeElement | null;
  querySelectorAll: (selector: string) => FakeElement[];
};

// A document with a section for each slide, and the list of the steps that
// the renderer writes for the same slides.
function fakeDocument(maxSteps: number[]): FakeDocument {
  const slides: FakeElement[] = maxSteps.map((max, index) => ({
    id: `slide-${index + 1}`,
    dataset: { maxStep: String(max) },
    style: { display: "none" },
  }));
  const list: FakeElement = {
    id: "expresso-deck",
    dataset: {},
    style: { display: "none" },
    textContent: json(deckOf(maxSteps)),
  };
  const all = [...slides, list];

  const doc: FakeDocument = {
    body: fakeBody(),
    slides,
    list,
    getElementsByClassName: (name) => (name === "slide" ? slides : []),
    getElementById: (id) => all.find((each) => each.id === id) ?? null,
    querySelectorAll: () => [],
  };

  (globalThis as unknown as { document: unknown }).document = doc;
  return doc;
}

// A state of a deck, with no black screen and no digits.
function at(
  deck: Deck,
  slide: number,
  step: number,
  view: View = "present",
): State {
  return atIn(deck, slide, step, view);
}

test("deck reads the list of the steps from the document", () => {
  fakeDocument([1, 3, 2]);

  assert.deepEqual(deck(), deckOf([1, 3, 2]));
});

test("deck reads an empty list for a document with no slide", () => {
  fakeDocument([]);

  assert.deepEqual(deck(), deckOf([]));
});

test("deck throws for a document with no list, or a list that is not valid", () => {
  const doc = fakeDocument([1]);
  doc.list.textContent = "{}";
  assert.throws(() => deck(), {
    message: "The list of the steps is not valid",
  });

  doc.list.id = "";
  assert.throws(() => deck(), {
    message: "The document has no list of the steps",
  });
});

test("apply shows the slide of the state and hides each other slide", () => {
  const doc = fakeDocument([1, 3, 2]);
  const list = deck();

  apply(at(list, 2, 3), list, program);

  assert.deepEqual(
    doc.slides.map((slide) => slide.style.display),
    ["none", "flex", "none"],
  );
});

test("apply writes the step of the state on the slide of the state", () => {
  const doc = fakeDocument([1, 3]);
  const list = deck();

  apply(at(list, 2, 3), list, program);

  assert.equal(nth(doc.slides, 1).dataset.step, "3");
  assert.equal(nth(doc.slides, 0).dataset.step, undefined);
});

test("apply writes the view on the body", () => {
  const doc = fakeDocument([1]);
  const list = deck();

  apply(at(list, 1, 1, "handout"), list, program);
  assert.equal(doc.body.dataset.view, "handout");

  apply(at(list, 1, 1), list, program);
  assert.equal(doc.body.dataset.view, "present");
});

test("apply writes the view only for a document with no slide", () => {
  const doc = fakeDocument([]);

  apply({ ...at(deckOf([1]), 1, 1), view: "handout" }, deck(), program);

  assert.equal(doc.body.dataset.view, "handout");
});

test("apply throws for a slide that the document does not hold", () => {
  fakeDocument([1]);
  const list = deckOf([1, 1]);

  assert.throws(() => apply(at(list, 2, 1), list, program), {
    message: "The document has no slide 2",
  });
});

test("apply writes data-blank for a black screen, and removes it after", () => {
  const doc = fakeDocument([1]);
  const list = deck();

  apply({ ...at(list, 1, 1), blank: true }, list, program);
  assert.equal(doc.body.dataset.blank, "true");

  apply(at(list, 1, 1), list, program);
  assert.equal("blank" in doc.body.dataset, false);
});

test("apply writes the flags of the state only while they are true", () => {
  const doc = fakeDocument([1]);
  const list = deck();

  apply({ ...at(list, 1, 1), overview: true, help: true }, list, program);
  assert.equal(doc.body.dataset.overview, "true");
  assert.equal(doc.body.dataset.help, "true");
  assert.equal(doc.body.dataset.progress, "true");

  apply({ ...at(list, 1, 1), progress: false }, list, program);
  assert.equal("overview" in doc.body.dataset, false);
  assert.equal("help" in doc.body.dataset, false);
  assert.equal(doc.body.dataset.progress, "false");
});

test("apply writes the part of the deck before the current step into --fraction", () => {
  const doc = fakeDocument([1, 3]);
  const list = deck();

  apply(at(list, 2, 2), list, program);
  assert.equal(doc.body.style.properties["--fraction"], "0.6667");

  const empty = fakeDocument([]);
  apply({ ...at(list, 1, 1), index: 0 }, deckOf([]), program);
  assert.equal(empty.body.style.properties["--fraction"], "0");
});
