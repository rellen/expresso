// The code that reads the document and writes to it.
//
// `state.ts` does not touch the document, and this module does not decide the
// next state. `main.ts` connects the two.

import type { Limits, State } from "./state.ts";

// The renderer gives each slide a `section` with the class `slide` and the
// identifier `slide-<number>`. The first slide is slide 1.
export function limits(): Limits {
  return { slides: document.getElementsByClassName("slide").length };
}

// Read a slide by its number. A missing slide is a defect of the renderer, so
// an error here is correct.
function slide(number: number): HTMLElement {
  const element = document.getElementById(`slide-${number}`);
  if (element === null) {
    throw new Error(`The document has no slide ${number}`);
  }
  return element;
}

// Show the slide of the state, and hide each other slide.
export function apply(state: State, limits: Limits): void {
  for (let number = 1; number <= limits.slides; number++) {
    slide(number).style.display = "none";
  }
  slide(state.slide).style.display = "flex";
}

// Show each slide, for a printer.
export function showAll(limits: Limits): void {
  for (let number = 1; number <= limits.slides; number++) {
    slide(number).style.display = "flex";
  }
}
