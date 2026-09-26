import { test } from "node:test";
import assert from "node:assert/strict";
import fc from "fast-check";
import {
  BINDINGS,
  columns,
  done,
  fraction,
  fromHash,
  initial,
  isMessage,
  maxStep,
  message,
  next,
  point,
  stamp,
  swipe,
  SWIPE,
  toHash,
  upcoming,
} from "../src/state.ts";
import type { Limits, State } from "../src/state.ts";

const limits: fc.Arbitrary<Limits> = fc
  .array(fc.integer({ min: 1, max: 5 }), { minLength: 1, maxLength: 8 })
  .map((steps) => ({ slides: steps.length, steps }));

const knownKeys = [...new Set(BINDINGS.flatMap((binding) => binding.keys))];

const key: fc.Arbitrary<string> = fc.oneof(
  { weight: 8, arbitrary: fc.constantFrom(...knownKeys) },
  { weight: 2, arbitrary: fc.string({ maxLength: 3 }) },
);

const deckAndPosition: fc.Arbitrary<[Limits, State]> = limits.chain((deck) =>
  fc
    .integer({ min: 1, max: deck.slides })
    .chain((slide) =>
      fc
        .integer({ min: 1, max: maxStep(slide, deck) })
        .map((step): [Limits, State] => [deck, { ...initial(), slide, step }]),
    ),
);

function forwardAll(state: State, deck: Limits): State[] {
  const states = [state];
  for (
    let after = upcoming(state, deck);
    after;
    after = upcoming(after, deck)
  ) {
    states.push(after);
  }
  return states;
}

test("each sequence of keys keeps the slide, the step and the selection inside the deck", () => {
  fc.assert(
    fc.property(limits, fc.array(key, { maxLength: 40 }), (deck, sequence) => {
      let state = initial();
      for (const pressed of sequence) {
        state = next(state, pressed, deck);
        assert.ok(state.slide >= 1 && state.slide <= deck.slides);
        assert.ok(state.step >= 1 && state.step <= maxStep(state.slide, deck));
        assert.ok(state.selected >= 1 && state.selected <= deck.slides);
        assert.match(state.digits, /^\d*$/);
      }
    }),
  );
});

test("a move forward and a move back give the same position, except at the end of the deck", () => {
  fc.assert(
    fc.property(deckAndPosition, ([deck, state]) => {
      const ahead = point(state, "forward", deck);
      fc.pre(ahead !== state);
      const back = point(ahead, "back", deck);
      assert.deepEqual([back.slide, back.step], [state.slide, state.step]);
    }),
  );
});

test("fraction and done grow with each step, from 0 to 1", () => {
  fc.assert(
    fc.property(limits, (deck) => {
      const states = forwardAll(initial(), deck);
      const fractions = states.map((state) => fraction(state, deck));
      const parts = states.map((state) => done(state, deck));

      assert.equal(
        states.length,
        deck.steps.reduce((sum, steps) => sum + steps, 0),
      );
      assert.equal(fractions[0], 0);
      assert.equal(parts[0], 0);
      assert.equal(fractions[fractions.length - 1], states.length > 1 ? 1 : 0);
      assert.ok(parts[parts.length - 1]! < 1);
      for (let index = 1; index < states.length; index++) {
        assert.ok(fractions[index]! > fractions[index - 1]!);
        assert.ok(parts[index]! > parts[index - 1]!);
      }
    }),
  );
});

test("the fragment of a position gives the same position back", () => {
  fc.assert(
    fc.property(deckAndPosition, ([deck, state]) => {
      const elsewhere = { ...initial(), slide: 1, step: 1 };
      const read = fromHash(elsewhere, toHash(state), deck);
      assert.deepEqual([read.slide, read.step], [state.slide, state.step]);
      assert.equal(fromHash(state, toHash(state), deck), state);
    }),
  );
});

test("a fragment of no position gives the same state", () => {
  fc.assert(
    fc.property(
      deckAndPosition,
      fc.string().filter((hash) => !/^#\d+(\.\d+)?$/.test(hash)),
      ([deck, state], hash) => {
        assert.equal(fromHash(state, hash, deck), state);
      },
    ),
  );
});

test("columns gives a grid with as many rows as columns or fewer, and no empty column", () => {
  fc.assert(
    fc.property(fc.integer({ min: 1, max: 10_000 }), (slides) => {
      const width = columns(slides);
      assert.ok(Math.ceil(slides / width) <= width);
      assert.ok(width === 1 || (width - 1) * (width - 1) < slides);
    }),
  );
});

test("swipe needs a long horizontal movement, and a swipe to the other side goes the other way", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: -500, max: 500 }),
      fc.integer({ min: -500, max: 500 }),
      (dx, dy) => {
        const result = swipe(dx, dy);
        if (Math.abs(dx) < SWIPE || Math.abs(dx) <= Math.abs(dy)) {
          assert.equal(result, undefined);
        } else {
          assert.equal(result, dx < 0 ? "forward" : "back");
          assert.equal(swipe(-dx, dy), dx < 0 ? "back" : "forward");
        }
      },
    ),
  );
});

test("stamp always increases, and never goes before the clock", () => {
  fc.assert(
    fc.property(fc.nat(), fc.nat(), (last, now) => {
      const time = stamp(last, now);
      assert.ok(time > last);
      assert.ok(time >= now);
      assert.ok(time === now || time === last + 1);
    }),
  );
});

test("each message of a state is a message of the presenter", () => {
  fc.assert(
    fc.property(
      deckAndPosition,
      fc.boolean(),
      fc.nat(),
      ([, state], blank, time) => {
        assert.ok(isMessage(message({ ...state, blank }, time)));
      },
    ),
  );
});
