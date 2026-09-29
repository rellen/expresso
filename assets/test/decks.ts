// The lists of the steps for the tests. `Expresso.Steps` makes the list in
// Elixir, and its tests examine each value. This module makes the same list
// from the number of steps of each slide, so a test of the script can give a
// deck with no renderer.

import { indexOf } from "../src/deck.ts";
import type { Deck, Entry, Kind } from "../src/deck.ts";
import { initial } from "../src/state.ts";
import type { State, View } from "../src/state.ts";

type Options = {
  // The kind of each slide, in slide order. A slide without an entry fades.
  kinds?: readonly Kind[] | undefined;
  // The length of the talk in milliseconds.
  duration?: number | null;
};

// Four decimal places, as `Expresso.Steps` gives.
function round(value: number): number {
  return Math.round(value * 10_000) / 10_000;
}

// A deck with the number of steps of each slide, in slide order.
export function deckOf(counts: readonly number[], options: Options = {}): Deck {
  const total = counts.reduce((sum, steps) => sum + steps, 0);
  const steps: Entry[] = [];
  counts.forEach((count, index) => {
    for (let step = 1; step <= count; step++) {
      const before = steps.length;
      const slide = `Slide ${index + 1} of ${counts.length}`;
      steps.push({
        slide: index + 1,
        step,
        fraction: total > 1 ? round(before / (total - 1)) : 0,
        done: round(before / total),
        position: count > 1 ? `${slide}, step ${step} of ${count}` : slide,
      });
    }
  });
  let first = 0;
  const slides = counts.map((count, index) => {
    const slide = {
      first,
      steps: count,
      transition: options.kinds?.[index] ?? "fade",
    };
    first += count;
    return slide;
  });
  return { steps, slides, duration: options.duration ?? null };
}

// The JSON text that the renderer writes for a deck.
export function json(deck: Deck): string {
  return JSON.stringify({
    steps: deck.steps.map((entry) => [
      entry.slide,
      entry.step,
      entry.fraction,
      entry.done,
      entry.position,
    ]),
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
  return { ...initial(), index, view };
}
