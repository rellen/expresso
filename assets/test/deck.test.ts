import { test } from "node:test";
import assert from "node:assert/strict";
import { indexOf, indexOfNumber, move, parse } from "../src/deck.ts";
import { raw } from "./fixtures.ts";
import { DecodeError } from "../src/decode.ts";
import { isKind, validateDeck } from "./validate.ts";
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
    '{"duration_ms":300000,"slides":[{"first":0,"number":1,"steps":1,"transition":"fade"},' +
    '{"first":1,"number":2,"steps":2,"transition":"fade"}],' +
    '"steps":[[1,1,0.0,0.0,"Slide 1 of 2",null,1],' +
    '[2,1,0.5,0.3333,"Slide 2 of 2, step 1 of 2",0,2],' +
    '[2,2,1.0,0.6667,"Slide 2 of 2, step 2 of 2",1,null]]}';

  assert.deepEqual(parse(text), deckOf([1, 2], { duration: 300_000 }));
});

test("deckOf makes the list of Expresso.Steps for a deck with a hidden slide", () => {
  // The text that `Expresso.Steps.json/1` gives for four slides of 1, 2, 1
  // and 2 steps, with slide 2 hidden.
  const text =
    '{"duration_ms":null,"slides":[{"first":0,"number":1,"steps":1,"transition":"fade"},' +
    '{"first":1,"number":null,"steps":2,"transition":"fade"},' +
    '{"first":3,"number":2,"steps":1,"transition":"fade"},' +
    '{"first":4,"number":3,"steps":2,"transition":"fade"}],' +
    '"steps":[[1,1,0.0,0.0,"Slide 1 of 3",null,3],' +
    '[2,1,0.0,0.0,"Hidden slide after slide 1 of 3, step 1 of 2",0,2],' +
    '[2,2,0.0,0.0,"Hidden slide after slide 1 of 3, step 2 of 2",1,3],' +
    '[3,1,0.3333,0.25,"Slide 2 of 3",0,4],' +
    '[4,1,0.6667,0.5,"Slide 3 of 3, step 1 of 2",3,5],' +
    '[4,2,1.0,0.75,"Slide 3 of 3, step 2 of 2",4,null]]}';

  assert.deepEqual(parse(text), deckOf([1, 2, 1, 2], { hidden: [2] }));
});

test("deckOf makes the list of Expresso.Steps for a deck that starts with a hidden slide", () => {
  const text =
    '{"duration_ms":null,"slides":[{"first":0,"number":null,"steps":2,"transition":"fade"},' +
    '{"first":2,"number":1,"steps":1,"transition":"fade"}],' +
    '"steps":[[1,1,0.0,0.0,"Hidden slide before slide 1 of 1, step 1 of 2",null,1],' +
    '[1,2,0.0,0.0,"Hidden slide before slide 1 of 1, step 2 of 2",0,2],' +
    '[2,1,0.0,0.0,"Slide 1 of 1",null,null]]}';

  assert.deepEqual(parse(text), deckOf([2, 1], { hidden: [1] }));
});

test("move skips each hidden slide, and it goes through the steps of a hidden slide", () => {
  const deck = deckOf([1, 2, 1, 2], { hidden: [2] });

  // From slide 1, the next step is slide 3, and the step before slide 3 is
  // slide 1.
  assert.equal(move(deck, 0, 1), 3);
  assert.equal(move(deck, 3, -1), 0);
  assert.equal(move(deck, 0, 2), 4);
  // On the hidden slide, a move goes through its steps and then into the talk.
  assert.equal(move(deck, 1, 1), 2);
  assert.equal(move(deck, 2, 1), 3);
  assert.equal(move(deck, 1, -1), 0);
  // A move past an end of the talk returns undefined.
  assert.equal(move(deck, 0, -1), undefined);
  assert.equal(move(deck, 5, 1), undefined);
  assert.equal(move(deck, 4, 2), undefined);
  assert.equal(move(deck, 0, 0), 0);
});

test("indexOfNumber gives step 1 of the slide of the talk with a number", () => {
  const deck = deckOf([1, 2, 1, 2], { hidden: [2] });

  assert.equal(indexOfNumber(deck, 1), 0);
  assert.equal(indexOfNumber(deck, 2), 3);
  assert.equal(indexOfNumber(deck, 3), 4);
  assert.equal(indexOfNumber(deck, 4), undefined);
  assert.equal(indexOfNumber(deck, 0), undefined);
});

test("validateDeck refuses a text that is not a list of the renderer", () => {
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
      slides: [{ first: 0, steps: 1, transition: "wipe_down" }],
    }),
    JSON.stringify({
      ...good,
      slides: [{ first: -1, steps: 1, transition: "fade" }],
    }),
  ];
  for (const text of texts) {
    assert.throws(() => validateDeck(text), DecodeError, text);
  }
});

// The script trusts the list, so this test examines each list of the fixture
// file.
test("each list of the fixture file is valid, and parse reads it as validateDeck does", () => {
  for (const [name, { deck }] of Object.entries(raw.decks)) {
    const text = JSON.stringify(deck);
    assert.deepEqual(parse(text), validateDeck(text), name);
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
  for (const kind of ["none", "fade", "slide", "zoom", "wipe-down", "Spin2"]) {
    assert.equal(isKind(kind), true, kind);
  }
  for (const value of [undefined, null, 1, "", "wipe_down", "fade ", '"]']) {
    assert.equal(isKind(value), false, String(value));
  }
});
