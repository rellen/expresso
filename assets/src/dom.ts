// The code that reads the document and writes to it.
//
// `state.ts` does not touch the document, and this module does not decide the
// next state. `main.ts` connects the two.

import type { Limits, State } from "./state.ts";

// The renderer gives each slide a `section` with the class `slide`, the
// identifier `slide-<number>` and the attribute `data-max-step`. The first
// slide is slide 1.
export function limits(): Limits {
  const count = document.getElementsByClassName("slide").length;
  const steps: number[] = [];
  for (let number = 1; number <= count; number++) {
    steps.push(Number(slide(number).dataset.maxStep) || 1);
  }
  return { slides: count, steps };
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

// Show the slide of the state at the step of the state, and hide each other
// slide. The generated style block reads `data-step`, and this attribute is
// the one operation of the presenter on an overlay. docs/overlays.md gives
// the CSS contract.
export function apply(state: State, limits: Limits): void {
  for (let number = 1; number <= limits.slides; number++) {
    slide(number).style.display = "none";
  }
  const current = slide(state.slide);
  current.dataset.step = String(state.step);
  current.style.display = "flex";
}

// Show each slide at its last step, for a printer.
export function showAll(limits: Limits): void {
  for (let number = 1; number <= limits.slides; number++) {
    const element = slide(number);
    element.dataset.step = String(limits.steps[number - 1] ?? 1);
    element.style.display = "flex";
  }
}
