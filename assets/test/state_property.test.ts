import { test } from "node:test";
import assert from "node:assert/strict";
import fc from "fast-check";
import { indexOf } from "../src/deck.ts";
import type { Deck } from "../src/deck.ts";
import {
  accepts,
  binding,
  choose,
  columns,
  current,
  follow,
  fromHash,
  initial,
  isMessage,
  message,
  next,
  point,
  side,
  stamp,
  swipe,
  SWIPE,
  toHash,
  transition,
  upcoming,
} from "../src/state.ts";
import type { Pointer, State } from "../src/state.ts";
import {
  data,
  decks,
  fragment,
  key,
  reachable,
  RUNS,
  stateIn,
} from "./property.ts";

const DIGITS = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];

// A reachable state with no black screen and no list of keys.
const shown = reachable.map(([deck, state]): [Deck, State] => [
  deck,
  { ...state, blank: false, help: false },
]);

// A reachable state in the present view with no black screen, list of keys,
// overview or digits.
const idle = shown.map(([deck, state]): [Deck, State] => [
  deck,
  { ...state, view: "present", overview: false, digits: "" },
]);

// The slide and the step of a state.
function where(state: State, deck: Deck): [number, number] {
  const entry = current(state, deck);
  assert.ok(entry, `no entry at index ${state.index}`);
  return [entry.slide, entry.step];
}

test("a reachable state stays inside the deck", () => {
  fc.assert(
    fc.property(reachable, ([deck, state]) => {
      assert.ok(Number.isInteger(state.index));
      assert.ok(state.index >= 0 && state.index < deck.steps.length);
      assert.ok(state.selected >= 1 && state.selected <= deck.slides.length);
      assert.match(state.digits, /^\d*$/);
    }),
    { numRuns: RUNS },
  );
});

test("upcoming goes through each step of the deck one time, in sequence", () => {
  fc.assert(
    fc.property(decks, (deck) => {
      const indexes = [initial().index];
      for (
        let after = upcoming(initial(), deck);
        after;
        after = upcoming(after, deck)
      ) {
        indexes.push(after.index);
      }
      assert.deepEqual(
        indexes,
        deck.steps.map((_entry, index) => index),
      );
    }),
    { numRuns: RUNS },
  );
});

test("a forward key and then k give the same step, and a forward key that gives the same state is the end", () => {
  const forwardKeys = ["j", "ArrowRight", "ArrowDown", "PageDown", " "];
  fc.assert(
    fc.property(idle, fc.constantFrom(...forwardKeys), ([deck, state], key) => {
      const ahead = next(state, key, deck);
      if (ahead === state) {
        assert.equal(upcoming(state, deck), null);
        return;
      }
      assert.equal(next(ahead, "k", deck).index, state.index);
    }),
    { numRuns: RUNS },
  );
});

test("upcoming is null only at the last step of the last slide", () => {
  fc.assert(
    fc.property(reachable, ([deck, state]) => {
      const end = state.index === deck.steps.length - 1;
      assert.equal(upcoming(state, deck) === null, end);
    }),
    { numRuns: RUNS },
  );
});

test("the fragment of a state gives the slide and the step of the state", () => {
  fc.assert(
    fc.property(reachable, ([deck, state]) => {
      const read = fromHash(initial(), toHash(state, deck), deck);
      assert.equal(read.index, state.index);
    }),
    { numRuns: RUNS },
  );
});

test("a fragment gives a slide and a step of the deck, and #4 is step 1 of slide 4; other fragments give the same state", () => {
  fc.assert(
    fc.property(
      decks.chain((deck) =>
        fc.tuple(fc.constant(deck), stateIn(deck), fragment(deck)),
      ),
      ([deck, state, hash]) => {
        const read = fromHash(state, hash, deck);
        const match = /^#(\d+)(?:\.(\d+))?$/.exec(hash);
        const slide = Number(match?.[1]);
        const step = match?.[2] === undefined ? 1 : Number(match[2]);
        const index = match === null ? undefined : indexOf(deck, slide, step);
        if (index !== undefined) {
          assert.deepEqual(where(read, deck), [slide, step]);
        } else {
          assert.equal(read, state);
        }
      },
    ),
    { numRuns: RUNS },
  );
});

test("the message of a state is a message, and follow of it gives the slide, the step and the black screen", () => {
  fc.assert(
    fc.property(
      decks.chain((deck) =>
        fc.tuple(fc.constant(deck), stateIn(deck), stateIn(deck), fc.nat()),
      ),
      ([deck, sender, receiver, time]) => {
        const sent = message(sender, deck, time);
        assert.ok(isMessage(sent));
        const read = follow(receiver, sent, deck);
        assert.deepEqual(
          [read.index, read.blank],
          [sender.index, sender.blank],
        );
      },
    ),
    { numRuns: RUNS },
  );
});

test("follow gives the same state for data that is not a message, or that gives no slide and step of the deck", () => {
  fc.assert(
    fc.property(
      decks.chain((deck) =>
        fc.tuple(fc.constant(deck), stateIn(deck), data(deck)),
      ),
      ([deck, state, sent]) => {
        const read = follow(state, sent, deck);
        const inside =
          isMessage(sent) && indexOf(deck, sent.slide, sent.step) !== undefined;
        if (!inside) {
          assert.equal(read, state);
        }
      },
    ),
    { numRuns: RUNS },
  );
});

// A time in milliseconds. The small times give two windows the same time.
const time = fc.oneof(fc.nat({ max: 3 }), fc.nat());

test("of two windows at the times p and q, exactly one takes the state of the other", () => {
  fc.assert(
    fc.property(time, time, (p, q) => {
      assert.notEqual(accepts(p, q, false), accepts(q, p, true));
    }),
    { numRuns: RUNS },
  );
});

test("stamp is more than the last time, and not less than the clock", () => {
  fc.assert(
    fc.property(fc.nat(), fc.nat(), (last, now) => {
      const time = stamp(last, now);
      assert.ok(time > last);
      assert.ok(time >= now);
      assert.ok(time === now || time === last + 1);
    }),
    { numRuns: RUNS },
  );
});

test("the slide with the higher number gives the kind of a transition in the two directions", () => {
  fc.assert(
    fc.property(
      decks.chain((deck) =>
        fc.tuple(fc.constant(deck), stateIn(deck), stateIn(deck)),
      ),
      ([deck, a, b]) => {
        const there = transition(a, b, deck);
        const back = transition(b, a, deck);
        if (there === null || back === null) {
          assert.equal(there, back);
          return;
        }
        const [from] = where(a, deck);
        const [to] = where(b, deck);
        const higher = deck.slides[Math.max(from, to) - 1]?.transition;
        assert.equal(there.kind, higher);
        assert.equal(back.kind, higher);
        assert.notEqual(there.direction, back.direction);
        assert.equal(there.direction, to > from ? "forward" : "back");
      },
    ),
    { numRuns: RUNS },
  );
});

test("a change of the slide in the present view with no black screen, overview or list of keys has a transition, except the kind none", () => {
  fc.assert(
    fc.property(
      decks.chain((deck) =>
        fc.tuple(fc.constant(deck), stateIn(deck), stateIn(deck)),
      ),
      ([deck, a, b]) => {
        const quiet = (state: State) =>
          state.view !== "present" ||
          state.blank ||
          state.overview ||
          state.help;
        const [from] = where(a, deck);
        const [to] = where(b, deck);
        const kind = deck.slides[Math.max(from, to) - 1]?.transition;
        const moves = from !== to && !quiet(a) && !quiet(b) && kind !== "none";
        assert.equal(transition(a, b, deck) !== null, moves);
      },
    ),
    { numRuns: RUNS },
  );
});

test("a key that has no function gives the same state", () => {
  fc.assert(
    fc.property(
      shown.map(([deck, state]): [Deck, State] => [
        deck,
        { ...state, digits: "" },
      ]),
      key,
      ([deck, state], pressed) => {
        fc.pre(binding(state, pressed) === undefined);
        assert.equal(next(state, pressed, deck), state);
      },
    ),
    { numRuns: RUNS },
  );
});

test("on a black screen or on the list of keys, each key and each click closes it, and does nothing more", () => {
  fc.assert(
    fc.property(
      shown,
      fc.constantFrom("blank", "help"),
      key,
      fc.constantFrom<Pointer>("forward", "back"),
      ([deck, state], cover, pressed, pointer) => {
        const covered =
          cover === "blank"
            ? { ...state, blank: true }
            : { ...state, help: true };
        assert.deepEqual(next(covered, pressed, deck), state);
        assert.deepEqual(point(covered, pointer, deck), state);
      },
    ),
    { numRuns: RUNS },
  );
});

test("a digit adds to the slide number, Enter goes to step 1 of that slide, and each other key removes the digits", () => {
  const typed = fc
    .array(fc.constantFrom(...DIGITS), { maxLength: 3 })
    .map((digits) => digits.join(""));
  fc.assert(
    fc.property(
      shown,
      fc.constantFrom<"present" | "speaker">("present", "speaker"),
      typed,
      key,
      ([deck, state], view, digits, pressed) => {
        const typing = { ...state, view, overview: false, digits };
        const after = next(typing, pressed, deck);
        const action = binding(typing, pressed)?.action;
        if (action === "digit") {
          assert.equal(after.digits, digits + pressed);
          return;
        }
        assert.equal(after.digits, "");
        if (action !== "go") {
          return;
        }
        const index =
          digits === "" ? undefined : indexOf(deck, Number(digits), 1);
        assert.equal(after.index, index ?? state.index);
      },
    ),
    { numRuns: RUNS },
  );
});

test("in the overview, o and Escape close it with the same step, and Enter goes to step 1 of the selected slide", () => {
  fc.assert(
    fc.property(
      shown.chain(([deck, state]) =>
        fc
          .integer({ min: 1, max: deck.slides.length })
          .map((selected): [Deck, State] => [
            deck,
            { ...state, overview: true, selected },
          ]),
      ),
      ([deck, state]) => {
        for (const close of ["o", "Escape"]) {
          assert.deepEqual(next(state, close, deck), {
            ...state,
            overview: false,
          });
        }
        const picked = next(state, "Enter", deck);
        assert.equal(picked.overview, false);
        assert.deepEqual(where(picked, deck), [state.selected, 1]);
      },
    ),
    { numRuns: RUNS },
  );
});

test("choose closes the overview and goes to step 1 of a slide, and for a number that is not a slide it only closes the overview", () => {
  fc.assert(
    fc.property(
      reachable.chain(([deck, state]) =>
        fc.tuple(
          fc.constant(deck),
          fc.constant(state),
          fc.integer({ min: -2, max: deck.slides.length + 2 }),
        ),
      ),
      ([deck, state, slide]) => {
        const chosen = choose(state, slide, deck);
        const index = indexOf(deck, slide, 1);
        if (index !== undefined) {
          assert.deepEqual(chosen, { ...state, overview: false, index });
        } else {
          assert.deepEqual(chosen, { ...state, overview: false });
        }
      },
    ),
    { numRuns: RUNS },
  );
});

test("a click, a tap or a swipe in the handout view or in the overview gives the same state", () => {
  fc.assert(
    fc.property(
      shown,
      fc.constantFrom("handout", "overview"),
      fc.constantFrom<Pointer>("forward", "back"),
      ([deck, state], where, pointer) => {
        const still =
          where === "handout"
            ? { ...state, view: "handout" as const, overview: false }
            : { ...state, overview: true };
        assert.equal(point(still, pointer, deck), still);
      },
    ),
    { numRuns: RUNS },
  );
});

test("columns gives the smallest number of columns with as many rows as columns or fewer", () => {
  fc.assert(
    fc.property(fc.integer({ min: 1, max: 100_000 }), (slides) => {
      const width = columns(slides);
      assert.ok(width * width >= slides);
      assert.ok(width === 1 || (width - 1) * (width - 1) < slides);
    }),
    { numRuns: RUNS },
  );
});

test("the left third of a window goes back, and the rest goes forward", () => {
  fc.assert(
    fc.property(
      fc
        .integer({ min: 1, max: 4000 })
        .chain((width) =>
          fc.tuple(fc.constant(width), fc.integer({ min: 0, max: width - 1 })),
        ),
      ([width, x]) => {
        assert.equal(side(x, width), x < width / 3 ? "back" : "forward");
      },
    ),
    { numRuns: RUNS },
  );
});

test("a swipe to the left goes forward, a short or a vertical movement has no function, and the opposite swipe goes the other way", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: -500, max: 500 }),
      fc.integer({ min: -500, max: 500 }),
      (dx, dy) => {
        const result = swipe(dx, dy);
        const opposite = swipe(-dx, dy);
        if (Math.abs(dx) < SWIPE || Math.abs(dx) <= Math.abs(dy)) {
          assert.equal(result, undefined);
          assert.equal(opposite, undefined);
        } else {
          assert.equal(result, dx < 0 ? "forward" : "back");
          assert.equal(opposite, dx < 0 ? "back" : "forward");
        }
      },
    ),
    { numRuns: RUNS },
  );
});
