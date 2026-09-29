// The list of the steps of the deck.
//
// `Expresso.Steps` writes the list as JSON into the element
// `script#expresso-deck`, and `dom.ts` reads it at load. The state holds the
// index of the current step in `steps`, and the script reads each other value
// from the list. Elixir calculates each value, so this module only reads the
// values and makes sure of their types. It does not touch the document.

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

export const KINDS: readonly Kind[] = ["none", "fade", "slide", "zoom"];

// Tell if a value is a kind of transition.
export function isKind(value: unknown): value is Kind {
  return KINDS.some((kind) => kind === value);
}

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

// A list that the renderer did not write is a defect of the renderer, so an
// error here is correct.
function invalid(): Error {
  return new Error("The list of the steps is not valid");
}

function count(value: unknown): number {
  if (!Number.isInteger(value) || (value as number) < 0) {
    throw invalid();
  }
  return value as number;
}

function part(value: unknown): number {
  if (typeof value !== "number" || !(value >= 0 && value <= 1)) {
    throw invalid();
  }
  return value;
}

function entry(value: unknown): Entry {
  if (!Array.isArray(value) || value.length !== 5) {
    throw invalid();
  }
  const [slide, step, fraction, done, position] = value as unknown[];
  if (typeof position !== "string") {
    throw invalid();
  }
  return {
    slide: count(slide),
    step: count(step),
    fraction: part(fraction),
    done: part(done),
    position,
  };
}

function slide(value: unknown): Slide {
  if (typeof value !== "object" || value === null) {
    throw invalid();
  }
  const { first, steps, transition } = value as Record<string, unknown>;
  if (!isKind(transition)) {
    throw invalid();
  }
  return { first: count(first), steps: count(steps), transition };
}

// Read the JSON text of the list. A text that is not a list of the renderer
// throws an error.
export function parse(text: string): Deck {
  const data: unknown = JSON.parse(text);
  if (typeof data !== "object" || data === null) {
    throw invalid();
  }
  const { steps, slides, duration_ms } = data as Record<string, unknown>;
  if (!Array.isArray(steps) || !Array.isArray(slides)) {
    throw invalid();
  }
  if (
    duration_ms !== null &&
    !(Number.isFinite(duration_ms) && (duration_ms as number) > 0)
  ) {
    throw invalid();
  }
  return {
    steps: steps.map(entry),
    slides: slides.map(slide),
    duration: duration_ms as number | null,
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
