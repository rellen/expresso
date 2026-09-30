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

// The transition from one slide to the next in the present view.
export type Kind = "none" | "fade" | "slide" | "zoom";

// One slide of the deck. `first` is the index of its step 1 in `steps`.
// `transition` is the kind of the transition into the slide.
export type Slide = Readonly<{
  first: number;
  steps: number;
  transition: Kind;
}>;

// `duration` is the length of the talk in milliseconds, or null.
export type Deck = Readonly<{
  steps: readonly Entry[];
  slides: readonly Slide[];
  duration: number | null;
}>;

// The list as the renderer writes it. Each entry is an array.
type Written = Readonly<{
  steps: readonly (readonly [number, number, number, number, string])[];
  slides: readonly Slide[];
  duration_ms: number | null;
}>;

// Read the JSON text of the list.
export function parse(text: string): Deck {
  const { steps, slides, duration_ms }: Written = JSON.parse(text);
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
