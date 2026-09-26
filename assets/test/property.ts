// The generators of the property tests of the presenter script. docs/development.md
// gives the reason for 500 runs.

import fc from "fast-check";
import {
  BINDINGS,
  choose,
  follow,
  fromHash,
  initial,
  next,
  point,
} from "../src/state.ts";
import type { Limits, Pointer, State } from "../src/state.ts";

export const RUNS = 500;

// A deck of 1 to 12 slides, each with 1 to 6 steps.
export const limits: fc.Arbitrary<Limits> = fc
  .array(fc.integer({ min: 1, max: 6 }), { minLength: 1, maxLength: 12 })
  .map((steps) => ({ slides: steps.length, steps }));

const bound = [...new Set(BINDINGS.flatMap((binding) => binding.keys))];

// Each key of the table, and some keys that have no binding in any view.
export const key: fc.Arbitrary<string> = fc.oneof(
  { weight: 9, arbitrary: fc.constantFrom(...bound) },
  { weight: 1, arbitrary: fc.constantFrom("x", "Tab", "F5", "Shift") },
);

// A number of a slide or a step, inside and outside the deck.
function near(maximum: number): fc.Arbitrary<number> {
  return fc.integer({ min: -1, max: maximum + 2 });
}

export function fragment(deck: Limits): fc.Arbitrary<string> {
  return fc.oneof(
    fc.string(),
    near(deck.slides).map((slide) => `#${slide}`),
    fc
      .tuple(near(deck.slides), near(6))
      .map(([slide, step]) => `#${slide}.${step}`),
  );
}

export function data(deck: Limits): fc.Arbitrary<unknown> {
  return fc.oneof(
    { weight: 4, arbitrary: position(deck) },
    { weight: 1, arbitrary: fc.anything() },
  );
}

function position(deck: Limits) {
  return fc.record({
    expresso: fc.constant("position"),
    slide: near(deck.slides),
    step: near(6),
    blank: fc.boolean(),
    time: fc.nat(),
  });
}

type Event =
  | { kind: "key"; key: string }
  | { kind: "pointer"; pointer: Pointer }
  | { kind: "choose"; slide: number }
  | { kind: "fromHash"; hash: string }
  | { kind: "follow"; data: unknown };

function event(deck: Limits): fc.Arbitrary<Event> {
  return fc.oneof(
    {
      weight: 12,
      arbitrary: key.map((key): Event => ({ kind: "key", key })),
    },
    {
      weight: 1,
      arbitrary: fc
        .constantFrom<Pointer>("forward", "back")
        .map((pointer): Event => ({ kind: "pointer", pointer })),
    },
    {
      weight: 1,
      arbitrary: near(deck.slides).map((slide): Event => ({
        kind: "choose",
        slide,
      })),
    },
    {
      weight: 1,
      arbitrary: fragment(deck).map((hash): Event => ({
        kind: "fromHash",
        hash,
      })),
    },
    {
      weight: 1,
      arbitrary: data(deck).map((data): Event => ({ kind: "follow", data })),
    },
  );
}

function apply(state: State, event: Event, deck: Limits): State {
  switch (event.kind) {
    case "key":
      return next(state, event.key, deck);
    case "pointer":
      return point(state, event.pointer, deck);
    case "choose":
      return choose(state, event.slide, deck);
    case "fromHash":
      return fromHash(state, event.hash, deck);
    case "follow":
      return follow(state, event.data, deck);
  }
}

// A state that the presenter can get to in a deck: the first state of the
// present view or of the speaker view, after 0 to 60 events.
export function stateIn(deck: Limits): fc.Arbitrary<State> {
  return fc
    .tuple(
      fc.constantFrom<"present" | "speaker">("present", "speaker"),
      fc.array(event(deck), { maxLength: 60 }),
    )
    .map(([view, events]) =>
      events.reduce<State>((state, each) => apply(state, each, deck), {
        ...initial(),
        view,
      }),
    );
}

// A deck, and a state that the presenter can get to in that deck.
export const reachable: fc.Arbitrary<[Limits, State]> = limits.chain((deck) =>
  stateIn(deck).map((state): [Limits, State] => [deck, state]),
);
