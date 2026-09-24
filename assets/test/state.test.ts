import { test } from "node:test";
import assert from "node:assert/strict";
import {
  BINDINGS,
  binding,
  follow,
  fromHash,
  initial,
  isMessage,
  maxStep,
  message,
  next,
  toHash,
  upcoming,
} from "../src/state.ts";
import type { State, View } from "../src/state.ts";

// Three slides. Slide 2 has three steps, and slide 3 has two steps.
const three = { slides: 3, steps: [1, 3, 2] };

// A state with no black screen and no digits.
function at(slide: number, step: number, view: View = "present"): State {
  return { slide, step, view, blank: false, digits: "", help: false };
}

// Give the state after each key, in sequence.
function keys(state: State, sequence: string[], limits = three): State {
  return sequence.reduce((current, key) => next(current, key, limits), state);
}

test("the initial state is slide 1, step 1, in the present view", () => {
  assert.deepEqual(initial(), at(1, 1));
});

test("maxStep reads the entry of the slide, and gives 1 without an entry", () => {
  assert.equal(maxStep(2, three), 3);
  assert.equal(maxStep(1, { slides: 1, steps: [] }), 1);
});

test("j moves to the next step", () => {
  assert.deepEqual(next(at(2, 1), "j", three), at(2, 2));
});

test("j on the last step moves to the first step of the next slide", () => {
  assert.deepEqual(next(at(2, 3), "j", three), at(3, 1));
  assert.deepEqual(next(at(1, 1), "j", three), at(2, 1));
});

test("j on the last step of the last slide gives the same state", () => {
  const state = at(3, 2);
  assert.equal(next(state, "j", three), state);
});

test("k moves to the previous step", () => {
  assert.deepEqual(next(at(2, 3), "k", three), at(2, 2));
});

test("k on the first step moves to the last step of the previous slide", () => {
  assert.deepEqual(next(at(3, 1), "k", three), at(2, 3));
  assert.deepEqual(next(at(2, 1), "k", three), at(1, 1));
});

test("k on the first step of the first slide gives the same state", () => {
  const state = at(1, 1);
  assert.equal(next(state, "k", three), state);
});

test("p changes to the handout view, and p again changes back", () => {
  const handout = next(at(2, 2), "p", three);
  assert.deepEqual(handout, at(2, 2, "handout"));
  assert.deepEqual(next(handout, "p", three), at(2, 2));
});

test("j and k keep the view", () => {
  assert.deepEqual(next(at(2, 1, "handout"), "j", three), at(2, 2, "handout"));
  assert.deepEqual(next(at(2, 2, "handout"), "k", three), at(2, 1, "handout"));
});

test("an unknown key gives the same state", () => {
  const state = at(2, 2);
  assert.equal(next(state, "x", three), state);
});

test("a deck with no slide stays on slide 1, step 1", () => {
  const state = initial();
  const empty = { slides: 0, steps: [] };
  assert.equal(next(state, "j", empty), state);
  assert.equal(next(state, "k", empty), state);
});

test("a slide without an entry in steps has one step", () => {
  const limits = { slides: 2, steps: [] };
  assert.deepEqual(next(at(1, 1), "j", limits), at(2, 1));
  assert.deepEqual(next(at(2, 1), "k", limits), at(1, 1));
});

test("the arrow keys, the space bar and the page keys move as j and k do", () => {
  for (const key of ["ArrowRight", "ArrowDown", "PageDown", " "]) {
    assert.deepEqual(next(at(2, 3), key, three), at(3, 1), key);
  }
  for (const key of ["ArrowLeft", "ArrowUp", "PageUp"]) {
    assert.deepEqual(next(at(3, 1), key, three), at(2, 3), key);
  }
});

test("Home goes to the first slide, and End goes to step 1 of the last slide", () => {
  assert.deepEqual(next(at(2, 2), "Home", three), at(1, 1));
  assert.deepEqual(next(at(2, 2), "End", three), at(3, 1));
});

test("Home on step 1 of the first slide gives the same state", () => {
  const state = at(1, 1);
  assert.equal(next(state, "Home", three), state);
});

test("digits and Enter go to step 1 of that slide", () => {
  assert.deepEqual(keys(at(1, 1), ["3", "Enter"]), at(3, 1));
  assert.deepEqual(keys(at(3, 2), ["0", "2", "Enter"]), at(2, 1));
});

test("a digit adds to the digits, and does not move", () => {
  assert.deepEqual(keys(at(1, 1), ["1", "2"]), { ...at(1, 1), digits: "12" });
});

test("a number that is not a slide removes the digits, and the slide stays", () => {
  assert.deepEqual(keys(at(2, 2), ["9", "Enter"]), at(2, 2));
  assert.deepEqual(keys(at(2, 2), ["0", "Enter"]), at(2, 2));
});

test("Enter without digits gives the same state", () => {
  const state = at(2, 2);
  assert.equal(next(state, "Enter", three), state);
});

test("a key that is not a digit removes the digits", () => {
  assert.deepEqual(keys(at(1, 1), ["3", "j"]), at(2, 1));
  assert.deepEqual(keys(at(1, 1), ["3", "x"]), at(1, 1));
});

test("b gives a black screen, and the next key shows the slide again", () => {
  const blank = next(at(2, 2), "b", three);
  assert.deepEqual(blank, { ...at(2, 2), blank: true });
  assert.deepEqual(next(blank, "b", three), at(2, 2));
  assert.deepEqual(next(blank, "j", three), at(2, 2));
  assert.deepEqual(next(blank, "p", three), at(2, 2));
});

test("the handout view knows only j, k and p", () => {
  const state = at(2, 2, "handout");
  for (const key of [
    "ArrowRight",
    " ",
    "PageDown",
    "Home",
    "End",
    "b",
    "3",
    "Enter",
  ]) {
    assert.equal(next(state, key, three), state, key);
  }
});

test("toHash gives the slide and the step", () => {
  assert.equal(toHash(at(4, 2)), "#4.2");
});

test("fromHash reads a slide and a step, and a slide alone is step 1", () => {
  assert.deepEqual(fromHash(at(1, 1), "#2.3", three), at(2, 3));
  assert.deepEqual(fromHash(at(1, 1), "#3", three), at(3, 1));
  assert.deepEqual(
    fromHash(at(1, 1, "handout"), "#2.2", three),
    at(2, 2, "handout"),
  );
});

test("fromHash gives the same state for a fragment that the deck does not have", () => {
  const state = at(2, 2);
  for (const hash of [
    "",
    "#",
    "#0",
    "#4",
    "#2.0",
    "#2.4",
    "#1.2",
    "#x",
    "#2.2.1",
    "#slide-2",
  ]) {
    assert.equal(fromHash(state, hash, three), state, hash);
  }
});

test("fromHash for the current position gives the same state", () => {
  const state = at(2, 2);
  assert.equal(fromHash(state, "#2.2", three), state);
});

test("fromHash removes a black screen and the digits", () => {
  const state = { ...at(1, 1), blank: true, digits: "3" };
  assert.deepEqual(fromHash(state, "#2", three), at(2, 1));
});

test("the speaker view knows the keys of the present view, but not p", () => {
  const state = at(2, 2, "speaker");
  assert.deepEqual(next(state, "j", three), at(2, 3, "speaker"));
  assert.deepEqual(next(state, "b", three), { ...state, blank: true });
  assert.equal(next(state, "p", three), state);
});

test("upcoming gives the next step, and null at the end of the deck", () => {
  assert.deepEqual(upcoming(at(2, 2), three), at(2, 3));
  assert.deepEqual(upcoming(at(2, 3), three), at(3, 1));
  assert.equal(upcoming(at(3, 2), three), null);
});

test("message gives the slide, the step and the black screen", () => {
  assert.deepEqual(message({ ...at(2, 3), blank: true, digits: "4" }), {
    expresso: "position",
    slide: 2,
    step: 3,
    blank: true,
  });
});

test("isMessage accepts only a message of the presenter", () => {
  assert.equal(isMessage(message(at(1, 1))), true);
  const others = [
    null,
    "position",
    { expresso: "other", slide: 1, step: 1, blank: false },
    { expresso: "position", slide: "1", step: 1, blank: false },
    { expresso: "position", slide: 1.5, step: 1, blank: false },
    { expresso: "position", slide: 1, step: 1 },
  ];
  for (const data of others) {
    assert.equal(isMessage(data), false, JSON.stringify(data));
  }
});

test("follow moves to the position of a message, with its black screen", () => {
  const data = { expresso: "position", slide: 3, step: 2, blank: true };
  assert.deepEqual(follow(at(1, 1, "speaker"), data, three), {
    ...at(3, 2, "speaker"),
    blank: true,
  });
});

test("follow gives the same state for the same position or a position not in the deck", () => {
  const state = at(2, 2);
  assert.equal(follow(state, message(state), three), state);
  assert.equal(follow(state, message(at(4, 1)), three), state);
  assert.equal(follow(state, message(at(2, 4)), three), state);
  assert.equal(follow(state, { slide: 1 }, three), state);
});

test("? opens the list of keys in each view, and removes the digits", () => {
  for (const view of ["present", "handout", "speaker"] as View[]) {
    assert.deepEqual(next(at(2, 2, view), "?", three), {
      ...at(2, 2, view),
      help: true,
    });
  }
  assert.deepEqual(keys(at(1, 1), ["3", "?"]), { ...at(1, 1), help: true });
});

test("the next key closes the list of keys, and does nothing more", () => {
  const open = { ...at(2, 2), help: true };
  assert.deepEqual(next(open, "j", three), at(2, 2));
  assert.deepEqual(next(open, "?", three), at(2, 2));
  assert.deepEqual(next(open, "x", three), at(2, 2));
});

test("no key has two bindings in one view", () => {
  for (const view of ["present", "handout", "speaker"] as View[]) {
    const seen = new Set<string>();
    for (const each of BINDINGS.filter((b) => b.views.includes(view))) {
      for (const key of each.keys) {
        assert.equal(seen.has(key), false, `${view}: ${key}`);
        seen.add(key);
      }
    }
  }
});

test("binding finds the key in the view of the state only", () => {
  assert.equal(binding(at(1, 1), "s")?.action, "speaker");
  assert.equal(binding(at(1, 1, "speaker"), "s"), undefined);
  assert.equal(binding(at(1, 1, "speaker"), "r")?.action, "reset");
  assert.equal(binding(at(1, 1), "r"), undefined);
  assert.equal(binding(at(1, 1, "handout"), "p")?.action, "present");
  assert.equal(binding(at(1, 1), "p")?.action, "handout");
});
