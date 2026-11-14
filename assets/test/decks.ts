// The lists of the steps for the tests. `Expresso.Steps` makes the list in
// Elixir, and its tests examine each value. This module makes the same list
// from the number of steps of each slide, so a test of the script can give a
// deck with no renderer.

import { indexOf } from "../src/deck.ts";
import { toWrittenEntry } from "../src/schema.ts";
import type { Deck, Entry, Kind } from "../src/deck.ts";
import type { State, View } from "../src/state.ts";
import { load } from "./fixtures.ts";

type Options = {
  // The kind of each slide, in slide order. A slide without an entry fades.
  kinds?: readonly Kind[] | undefined;
  // The length of the talk in milliseconds.
  duration?: number | null;
  // The place of each hidden slide in the deck. The first slide is 1.
  hidden?: readonly number[];
};

// Four decimal places, as `Expresso.Steps` gives.
function round(value: number): number {
  return Math.round(value * 10_000) / 10_000;
}

// The index of the nearest step in a direction that is a step of the same
// slide or of a slide of the talk, or null. `Expresso.Steps` has the same
// rule.
function near(
  places: readonly { slide: number; hidden: boolean }[],
  index: number,
  by: 1 | -1,
): number | null {
  const slide = places[index]?.slide;
  for (let at = index + by; at >= 0 && at < places.length; at += by) {
    const place = places[at];
    if (place !== undefined && (place.slide === slide || !place.hidden)) {
      return at;
    }
  }
  return null;
}

// A deck with the number of steps of each slide, in slide order. A hidden
// slide is not a part of the talk, as in `Expresso.Steps`.
export function deckOf(counts: readonly number[], options: Options = {}): Deck {
  const hidden = (index: number) =>
    options.hidden?.includes(index + 1) ?? false;
  const shown = counts.filter((_count, index) => !hidden(index));
  const count = shown.length;
  const total = shown.reduce((sum, steps) => sum + steps, 0);
  const places = counts.flatMap((steps, index) =>
    Array.from({ length: steps }, () => ({
      slide: index + 1,
      hidden: hidden(index),
    })),
  );
  const steps: Entry[] = [];
  // The number of slides and of steps of the talk in front of the step.
  let number = 0;
  let before = 0;
  counts.forEach((steps_of_slide, index) => {
    const slide = hidden(index)
      ? count === 0
        ? "Hidden slide"
        : number === 0
          ? `Hidden slide before slide 1 of ${count}`
          : `Hidden slide after slide ${number} of ${count}`
      : `Slide ${number + 1} of ${count}`;
    for (let step = 1; step <= steps_of_slide; step++) {
      const place = hidden(index) ? Math.max(before - 1, 0) : before;
      steps.push({
        slide: index + 1,
        step,
        fraction: total > 1 ? round(place / (total - 1)) : 0,
        done: total > 0 ? round(place / total) : 0,
        position:
          steps_of_slide > 1
            ? `${slide}, step ${step} of ${steps_of_slide}`
            : slide,
        previous: near(places, steps.length, -1),
        next: near(places, steps.length, 1),
      });
      before += hidden(index) ? 0 : 1;
    }
    number += hidden(index) ? 0 : 1;
  });
  let first = 0;
  let talk = 0;
  const slides = counts.map((steps_of_slide, index) => {
    const slide = {
      first,
      steps: steps_of_slide,
      transition: options.kinds?.[index] ?? "fade",
      number: hidden(index) ? null : ++talk,
    };
    first += steps_of_slide;
    return slide;
  });
  return { steps, slides, duration: options.duration ?? null };
}

// The JSON text that the renderer writes for a deck.
export function json(deck: Deck): string {
  return JSON.stringify({
    steps: deck.steps.map(toWrittenEntry),
    slides: deck.slides,
    duration_ms: deck.duration,
  });
}

// The state at a slide and a step, with no black screen and no digits. A
// slide and a step that the deck does not have stop the test.
export function at(
  deck: Deck,
  slide: number,
  step: number,
  view: View = "present",
): State {
  const index = indexOf(deck, slide, step);
  if (index === undefined) {
    throw new Error(`The deck has no step ${slide}.${step}`);
  }
  return { ...load("1,2").program.state, index, view };
}
