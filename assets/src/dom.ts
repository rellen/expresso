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

// Apply a state to the document. The function writes the view on the `body`,
// it shows the slide of the state at the step of the state, and it hides each
// other slide. A deck with no slide gets the view only. The style sheet reads `data-view`, and the generated style
// block reads `data-step`. These two attributes are the only operations of
// the presenter on the document. docs/overlays.md gives the CSS contract.
export function apply(state: State, limits: Limits): void {
  document.body.dataset.view = state.view;
  for (let number = 1; number <= limits.slides; number++) {
    slide(number).style.display = "none";
  }
  // A deck can hold no slide. The view still changes, and the function must
  // not read a slide that the document does not have.
  if (limits.slides === 0) {
    return;
  }
  const current = slide(state.slide);
  current.dataset.step = String(state.step);
  current.style.display = "flex";
}
