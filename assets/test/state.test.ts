import { test } from "node:test";
import assert from "node:assert/strict";
import {
  BINDINGS,
  accepts,
  binding,
  choose,
  columns,
  done,
  follow,
  fraction,
  fromHash,
  initial,
  isMessage,
  maxStep,
  message,
  mode,
  next,
  point,
  side,
  stamp,
  swipe,
  toHash,
  upcoming,
} from "../src/state.ts";
import type { State, View } from "../src/state.ts";

// Three slides. Slide 2 has three steps, and slide 3 has two steps.
const three = { slides: 3, steps: [1, 3, 2] };

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
    overview: false,
    selected: 1,
  };
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

test("the handout view does not know the other keys of the present view", () => {
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

test("message gives the slide, the step, the black screen and the time", () => {
  assert.deepEqual(message({ ...at(2, 3), blank: true, digits: "4" }, 17), {
    expresso: "position",
    slide: 2,
    step: 3,
    blank: true,
    time: 17,
  });
});

test("isMessage accepts only a message of the presenter", () => {
  assert.equal(isMessage(message(at(1, 1), 1)), true);
  const others = [
    null,
    "position",
    { expresso: "other", slide: 1, step: 1, blank: false, time: 1 },
    { expresso: "position", slide: "1", step: 1, blank: false, time: 1 },
    { expresso: "position", slide: 1.5, step: 1, blank: false, time: 1 },
    { expresso: "position", slide: 1, step: 1, time: 1 },
    { expresso: "position", slide: 1, step: 1, blank: false },
    { expresso: "position", slide: 1, step: 1, blank: false, time: "1" },
    { expresso: "position", slide: 1, step: 1, blank: false, time: NaN },
  ];
  for (const data of others) {
    assert.equal(isMessage(data), false, JSON.stringify(data));
  }
});

test("follow moves to the position of a message, with its black screen", () => {
  const data = {
    expresso: "position",
    slide: 3,
    step: 2,
    blank: true,
    time: 1,
  };
  assert.deepEqual(follow(at(1, 1, "speaker"), data, three), {
    ...at(3, 2, "speaker"),
    blank: true,
  });
});

test("follow gives the same state for the same position or a position not in the deck", () => {
  const state = at(2, 2);
  assert.equal(follow(state, message(state, 1), three), state);
  assert.equal(follow(state, message(at(4, 1), 1), three), state);
  assert.equal(follow(state, message(at(2, 4), 1), three), state);
  assert.equal(follow(state, { slide: 1 }, three), state);
});

test("stamp gives the clock, or one more than the last time", () => {
  assert.equal(stamp(0, 500), 500);
  assert.equal(stamp(500, 500), 501);
  assert.equal(stamp(900, 500), 901);
});

test("accepts takes a newer message, and ignores an older one", () => {
  for (const speaker of [true, false]) {
    assert.equal(accepts(10, 11, speaker), true);
    assert.equal(accepts(10, 9, speaker), false);
  }
});

test("at the same time, the speaker view takes the message and the present view keeps its state", () => {
  assert.equal(accepts(10, 10, true), true);
  assert.equal(accepts(10, 10, false), false);
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

test("g hides the progress bar in the present view, and g again shows it", () => {
  const hidden = next(at(2, 2), "g", three);
  assert.deepEqual(hidden, { ...at(2, 2), progress: false });
  assert.deepEqual(next(hidden, "g", three), at(2, 2));
});

test("g has no function in the handout view and the speaker view", () => {
  for (const view of ["handout", "speaker"] as View[]) {
    const state = at(2, 2, view);
    assert.equal(next(state, "g", three), state, view);
  }
});

test("fraction counts each step of each slide", () => {
  // Three slides of 1, 3 and 2 steps give six steps, and five moves.
  assert.equal(fraction(at(1, 1), three), 0);
  assert.equal(fraction(at(2, 1), three), 1 / 5);
  assert.equal(fraction(at(2, 3), three), 3 / 5);
  assert.equal(fraction(at(3, 1), three), 4 / 5);
  assert.equal(fraction(at(3, 2), three), 1);
});

test("fraction gives 0 for a deck of one step or no step", () => {
  assert.equal(fraction(at(1, 1), { slides: 1, steps: [1] }), 0);
  assert.equal(fraction(at(1, 1), { slides: 0, steps: [] }), 0);
});

test("a in the handout view shows every step, and a again shows the selection", () => {
  const every = next(at(2, 2, "handout"), "a", three);
  assert.deepEqual(every, { ...at(2, 2, "handout"), every: true });
  assert.deepEqual(next(every, "a", three), at(2, 2, "handout"));
});

test("a has no function in the present view and the speaker view", () => {
  for (const view of ["present", "speaker"] as View[]) {
    const state = at(2, 2, view);
    assert.equal(next(state, "a", three), state, view);
  }
});

test("side gives back for the left third, and forward for the rest", () => {
  assert.equal(side(0, 1200), "back");
  assert.equal(side(399, 1200), "back");
  assert.equal(side(400, 1200), "forward");
  assert.equal(side(1199, 1200), "forward");
});

test("swipe gives forward to the left, back to the right, and nothing else", () => {
  assert.equal(swipe(-50, 0), "forward");
  assert.equal(swipe(80, -30), "back");
  assert.equal(swipe(-49, 0), undefined);
  assert.equal(swipe(60, 60), undefined);
  assert.equal(swipe(0, -200), undefined);
});

test("point moves one step, as j and k do", () => {
  assert.deepEqual(point(at(1, 1), "forward", three), at(2, 1));
  assert.deepEqual(point(at(2, 1), "back", three), at(1, 1));
  assert.deepEqual(point(at(1, 1, "speaker"), "forward", three), {
    ...at(2, 1),
    view: "speaker",
  });
  assert.deepEqual(point(at(3, 2), "forward", three), at(3, 2));
});

test("point removes the digits", () => {
  const typed = { ...at(1, 1), digits: "3" };
  assert.deepEqual(point(typed, "forward", three), at(2, 1));
});

test("point closes a black screen or the list of keys, and does nothing more", () => {
  const blank = { ...at(2, 2), blank: true };
  assert.deepEqual(point(blank, "forward", three), at(2, 2));

  const help = { ...at(2, 2, "handout"), help: true };
  assert.deepEqual(point(help, "back", three), at(2, 2, "handout"));
});

test("point has no other function in the handout view", () => {
  const handout = at(2, 2, "handout");
  assert.equal(point(handout, "forward", three), handout);
  assert.equal(point(handout, "back", three), handout);
});

test("f is full screen in the present view and the speaker view only", () => {
  assert.equal(binding(at(1, 1), "f")?.action, "fullscreen");
  assert.equal(binding(at(1, 1, "speaker"), "f")?.action, "fullscreen");
  assert.equal(binding(at(1, 1, "handout"), "f"), undefined);
  assert.deepEqual(next(at(1, 1), "f", three), at(1, 1));
});

test("no key finds a row of a click or a swipe", () => {
  for (const row of BINDINGS.filter((each) => each.keys.length === 0)) {
    assert.ok(row.label, row.text);
  }
  assert.equal(binding(at(1, 1), ""), undefined);
});

// Seven slides of one step each give three columns.
const seven = { slides: 7, steps: [1, 1, 1, 1, 1, 1, 1] };

function grid(selected: number, slide = 4): State {
  return { ...at(slide, 1), overview: true, selected };
}

test("columns gives a grid with as many rows as columns or fewer", () => {
  assert.equal(columns(0), 1);
  assert.equal(columns(1), 1);
  assert.equal(columns(4), 2);
  assert.equal(columns(5), 3);
  assert.equal(columns(13), 4);
  for (let slides = 1; slides <= 100; slides++) {
    const width = columns(slides);
    assert.ok(Math.ceil(slides / width) <= width, String(slides));
  }
});

test("o opens the overview at the current slide in the present view and the speaker view", () => {
  assert.deepEqual(next(at(4, 1), "o", seven), grid(4));
  assert.deepEqual(next(at(2, 1, "speaker"), "o", seven), {
    ...grid(2, 2),
    view: "speaker",
  });
  assert.equal(binding(at(1, 1, "handout"), "o"), undefined);
});

test("mode is the overview while it shows", () => {
  assert.equal(mode(at(1, 1)), "present");
  assert.equal(mode(grid(1)), "overview");
  assert.equal(mode({ ...grid(1), view: "speaker" }), "overview");
});

test("the keys of the overview select a slide inside the deck", () => {
  assert.deepEqual(next(grid(4), "ArrowRight", seven), grid(5));
  assert.deepEqual(next(grid(4), "k", seven), grid(3));
  assert.deepEqual(next(grid(4), "ArrowDown", seven), grid(7));
  assert.deepEqual(next(grid(4), "ArrowUp", seven), grid(1));
  assert.deepEqual(next(grid(4), "End", seven), grid(7));
  assert.deepEqual(next(grid(4), "Home", seven), grid(1));

  for (const [selected, key] of [
    [7, "j"],
    [5, "ArrowDown"],
    [2, "ArrowUp"],
    [1, "ArrowLeft"],
  ] as const) {
    const state = grid(selected);
    assert.equal(next(state, key, seven), state, key);
  }
});

test("Enter goes to step 1 of the selected slide, and o or Escape keeps the step", () => {
  const deep = { ...grid(2), slide: 3, step: 2 };
  const limits = { slides: 7, steps: [1, 1, 3, 1, 1, 1, 1] };
  assert.deepEqual(next(deep, "Enter", limits), { ...at(2, 1), selected: 2 });
  assert.deepEqual(next(deep, "o", limits), { ...at(3, 2), selected: 2 });
  assert.deepEqual(next(deep, "Escape", limits), { ...at(3, 2), selected: 2 });
});

test("choose goes to step 1 of a slide, and closes the overview", () => {
  assert.deepEqual(choose(grid(1), 6, seven), { ...at(6, 1), selected: 1 });
  assert.deepEqual(choose(grid(1), 4, seven), { ...at(4, 1), selected: 1 });
  assert.deepEqual(choose(grid(1), 9, seven), { ...at(4, 1), selected: 1 });
});

test("the overview knows ?, and no key of the present view", () => {
  assert.deepEqual(next(grid(4), "?", seven), { ...grid(4), help: true });
  for (const key of ["b", "p", "s", "g", "f", "5", "PageDown"]) {
    const action = binding(grid(4), key)?.action;
    assert.ok(
      action === undefined || action === "forward",
      `${key}: ${action}`,
    );
  }
  const state = grid(4);
  assert.equal(next(state, "b", seven), state);
});

test("point does not move the overview", () => {
  const state = grid(4);
  assert.equal(point(state, "forward", seven), state);
  assert.deepEqual(point({ ...grid(4), help: true }, "back", seven), grid(4));
});

test("a message of the other window keeps the overview", () => {
  const moved = follow(
    grid(2),
    { expresso: "position", slide: 6, step: 1, blank: false, time: 1 },
    seven,
  );
  assert.deepEqual(moved, { ...grid(2, 6) });
});

test("done gives the part of the steps before the current step, with a part for the last step", () => {
  // Six steps: slide 1 has one, slide 2 has three, and slide 3 has two.
  assert.equal(done(at(1, 1), three), 0);
  assert.equal(done(at(2, 2), three), 2 / 6);
  assert.equal(done(at(3, 2), three), 5 / 6);
  assert.equal(done(at(1, 1), { slides: 0, steps: [] }), 0);
});
