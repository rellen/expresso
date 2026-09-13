// The state of the presenter, and the function that changes it.
//
// This module does not touch the document. `dom.ts` reads the document and
// applies a state to it. This split gives the state a unit test.
//
// The state holds the number of the current slide. The overlay design in
// docs/overlays.md adds the number of the step later.

export type State = {
  slide: number;
};

export type Limits = {
  slides: number;
};

// The first slide is slide 1. `Expresso.Deck.number_slides/1` gives the same
// number to the identifier of each section.
export function initial(): State {
  return { slide: 1 };
}

// Give the state after one key. An unknown key gives the same state.
//
// `j` moves to the next slide, and `k` moves to the previous slide. A move past
// the first slide or past the last slide gives the same state.
export function next(state: State, key: string, limits: Limits): State {
  if (key === "j" && state.slide < limits.slides) {
    return { slide: state.slide + 1 };
  }

  if (key === "k" && state.slide > 1) {
    return { slide: state.slide - 1 };
  }

  return state;
}
