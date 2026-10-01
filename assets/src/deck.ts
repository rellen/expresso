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

import type { Slide, WrittenDeck } from "./schema.ts";

// One step of the deck. `fraction` is the part of the deck before the step,
// from 0 to 1, and the progress bar shows it. `done` is the part of the steps
// before the step, and it is less than 1. `position` is the text of the
// speaker view, such as `Slide 4 of 13, step 2 of 3`.
export type Entry = Readonly<{
  slide: number;
  step: number;
  fraction: number;
  done: number;
  position: string;
}>;

// `Slide` is one slide of the deck: `first` is the index of its step 1 in
// `steps`, and `transition` is the kind of the transition into the slide.
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
    steps: steps.map(([slide, step, fraction, done, position]) => ({
      slide,
      step,
      fraction,
      done,
      position,
    })),
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
