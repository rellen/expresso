// The list of the steps of the deck.
//
// `Expresso.Steps` writes the list as JSON into the element
// `script#expresso-deck`, and `dom.ts` reads it at load. The state holds the
// index of the current step in `steps`, and the script reads each other value
// from the list. Elixir calculates each value, so this module only reads the
// values. It does not touch the document.
//
// The renderer writes the list and this script into the same document, so the
// script trusts the list, as it trusts the program. `assets/test/validate.ts`
// examines each list of the tests.

import { fromWrittenEntry } from "./schema.ts";
import type { Entry, Slide, WrittenDeck } from "./schema.ts";

// `Entry` is one step of the deck. `fraction` is the part of the talk before
// the step, from 0 to 1, and the progress bar shows it. `done` is the part of
// the steps before the step, and it is less than 1. `position` is the text of
// the speaker view, such as `Slide 4 of 13, step 2 of 3`. `previous` and
// `next` are the index of the step before it and of the step after it in the
// talk, or null at an end of the talk. They skip each hidden slide.
// `schema.ts` declares it, and the form `written_entry` of
// `Expresso.Presenter.Schema` gives the order of its values in the list.
export type { Entry } from "./schema.ts";

// `Slide` is one slide of the deck: `first` is the index of its step 1 in
// `steps`, `transition` is the kind of the transition into the slide, and
// `number` is its number in the talk, or null for a hidden slide.
// `schema.ts` declares it and `Kind`.
export type { Kind, Slide } from "./schema.ts";

// `duration` is the length of the talk in milliseconds, or null.
export type Deck = Readonly<{
  steps: readonly Entry[];
  slides: readonly Slide[];
  duration: number | null;
}>;

// Make an object of each entry. `parse` reads the text, and the tests read a
// list that `decodeWrittenDeck` returns.
export function fromWritten({ steps, slides, duration_ms }: WrittenDeck): Deck {
  return {
    steps: steps.map(fromWrittenEntry),
    slides,
    duration: duration_ms,
  };
}

// Read the JSON text of the list.
export function parse(text: string): Deck {
  return fromWritten(JSON.parse(text));
}

// The index of a slide and a step in `steps`, or undefined for a slide or a
// step that the deck does not have.
export function indexOf(
  deck: Deck,
  slide: number,
  step: number,
): number | undefined {
  const found = Number.isInteger(slide) ? deck.slides[slide - 1] : undefined;
  if (found === undefined || !Number.isInteger(step)) {
    return undefined;
  }
  if (step < 1 || step > found.steps) {
    return undefined;
  }
  return found.first + step - 1;
}

// The index of the step that is a number of steps of the talk after a step,
// or before it for a negative number. `Expresso.Steps` gives each step its
// `previous` and its `next`, which skip each hidden slide. A move past an end
// of the talk returns undefined.
export function move(
  deck: Deck,
  index: number,
  by: number,
): number | undefined {
  let at: number | undefined = index;
  for (let moves = Math.abs(by); moves > 0 && at !== undefined; moves--) {
    const entry: Entry | undefined = deck.steps[at];
    at = (by > 0 ? entry?.next : entry?.previous) ?? undefined;
  }
  return at;
}

// The index of step 1 of the slide of the talk with a number, or undefined. A
// hidden slide has no number.
export function indexOfNumber(deck: Deck, number: number): number | undefined {
  return deck.slides.find((slide) => slide.number === number)?.first;
}
