import { test } from "node:test";
import assert from "node:assert/strict";
import { indexOf, isKind, parse } from "../src/deck.ts";
import { deckOf, json } from "./decks.ts";

// Three slides. Slide 2 has three steps, and slide 3 has two steps.
const three = deckOf([1, 3, 2], { kinds: ["fade", "zoom", "none"] });

test("parse reads the list that the renderer writes", () => {
  assert.deepEqual(parse(json(three)), three);
  assert.deepEqual(parse(json(deckOf([], { duration: 60_000 }))), {
    steps: [],
    slides: [],
    duration: 60_000,
  });
});

test("parse reads the text of the renderer for a deck of two slides", () => {
  // The text that `Expresso.Steps.json/1` gives for the test "gives the steps
  // as arrays, the slides as objects and the duration".
  const text =
    '{"duration_ms":300000,"slides":[{"first":0,"steps":1,"transition":"fade"},' +
    '{"first":1,"steps":2,"transition":"fade"}],"steps":[[1,1,0.0,0.0,"Slide 1 of 2"],' +
    '[2,1,0.5,0.3333,"Slide 2 of 2, step 1 of 2"],[2,2,1.0,0.6667,"Slide 2 of 2, step 2 of 2"]]}';

  assert.deepEqual(parse(text), deckOf([1, 2], { duration: 300_000 }));
});

test("parse throws for a text that is not a list of the renderer", () => {
  const good = JSON.parse(json(three)) as Record<string, unknown>;
  const texts = [
    "null",
    "[]",
    JSON.stringify({ ...good, steps: {} }),
    JSON.stringify({ ...good, slides: null }),
    JSON.stringify({ ...good, duration_ms: 0 }),
    JSON.stringify({ ...good, duration_ms: "60000" }),
    JSON.stringify({ ...good, duration_ms: undefined }),
    JSON.stringify({ ...good, steps: [[1, 1, 0, 0]] }),
    JSON.stringify({ ...good, steps: [[1, 1, 0, 0, 5]] }),
    JSON.stringify({ ...good, steps: [[1.5, 1, 0, 0, "x"]] }),
    JSON.stringify({ ...good, steps: [[1, 1, 2, 0, "x"]] }),
    JSON.stringify({ ...good, steps: [[1, 1, 0, -1, "x"]] }),
    JSON.stringify({ ...good, slides: [{ first: 0, steps: 1 }] }),
    JSON.stringify({
      ...good,
      slides: [{ first: 0, steps: 1, transition: "wipe" }],
    }),
    JSON.stringify({
      ...good,
      slides: [{ first: -1, steps: 1, transition: "fade" }],
    }),
  ];
  for (const text of texts) {
    assert.throws(
      () => parse(text),
      { message: "The list of the steps is not valid" },
      text,
    );
  }
});

test("indexOf gives the index of a slide and a step", () => {
  assert.equal(indexOf(three, 1, 1), 0);
  assert.equal(indexOf(three, 2, 1), 1);
  assert.equal(indexOf(three, 2, 3), 3);
  assert.equal(indexOf(three, 3, 2), 5);
});

test("indexOf gives undefined for a slide or a step that the deck does not have", () => {
  for (const [slide, step] of [
    [0, 1],
    [4, 1],
    [1, 2],
    [2, 0],
    [2, 4],
    [1.5, 1],
    [2, 1.5],
    [NaN, 1],
  ] as const) {
    assert.equal(indexOf(three, slide, step), undefined, `${slide}.${step}`);
  }
});

test("isKind tells if a value is a kind of transition", () => {
  for (const kind of ["none", "fade", "slide", "zoom"]) {
    assert.equal(isKind(kind), true, kind);
  }
  for (const value of [undefined, null, 1, "", "Fade", "wipe", "fade "]) {
    assert.equal(isKind(value), false, String(value));
  }
});
