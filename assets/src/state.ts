// The state of the presenter, and the function that changes it.
//
// This module does not touch the document. `dom.ts` reads the document and
// applies a state to it. This split gives the state a unit test.
//
// The state holds the number of the current slide, the number of the current
// step in that slide, and the view. docs/overlays.md gives the rules of a step
// and the reason for the handout view.

// The present view shows one slide at one step. The handout view shows one page
// for each step of each slide.
export type View = "present" | "handout";

export type State = {
  slide: number;
  step: number;
  view: View;
};

// `steps` holds the maximum step number of each slide, in slide order. The
// entry for slide 1 is at index 0.
export type Limits = {
  slides: number;
  steps: number[];
};

// The first slide is slide 1, and the first step is step 1.
// `Expresso.Deck.number_slides/1` gives the same number to the identifier of
// each section.
export function initial(): State {
  return { slide: 1, step: 1, view: "present" };
}

// The maximum step number of a slide. A slide without an entry has one step.
export function maxStep(slide: number, limits: Limits): number {
  return limits.steps[slide - 1] ?? 1;
}

// Give the state after one key. An unknown key gives the same state.
//
// `j` moves to the next step, and to the first step of the next slide after
// the last step. `k` moves to the previous step, and to the last step of the
// previous slide at the first step. A move past the first slide or past the
// last slide gives the same state. `p` changes the view, and it keeps the
// slide and the step.
export function next(state: State, key: string, limits: Limits): State {
  if (key === "j") {
    if (state.step < maxStep(state.slide, limits)) {
      return { slide: state.slide, step: state.step + 1, view: state.view };
    }
    if (state.slide < limits.slides) {
      return { slide: state.slide + 1, step: 1, view: state.view };
    }
    return state;
  }

  if (key === "k") {
    if (state.step > 1) {
      return { slide: state.slide, step: state.step - 1, view: state.view };
    }
    if (state.slide > 1) {
      return {
        slide: state.slide - 1,
        step: maxStep(state.slide - 1, limits),
        view: state.view,
      };
    }
    return state;
  }

  if (key === "p") {
    const view: View = state.view === "present" ? "handout" : "present";
    return { slide: state.slide, step: state.step, view };
  }

  return state;
}
