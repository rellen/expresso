// The state of the presenter, and the function that changes it.
//
// This module does not touch the document. `dom.ts` reads the document and
// applies a state to it. This split gives the state a unit test.
//
// The state holds the number of the current slide, the number of the current
// step in that slide, and the view. docs/overlays.md gives the rules of a step
// and the reason for the handout view.

// The present view shows one slide at one step. The handout view shows one page
// for each step of each slide. The speaker view shows the current step, the
// next step and the notes, in a second window.
export type View = "present" | "handout" | "speaker";

// `blank` is true while the present view shows a black screen. `digits` holds
// the digits of a slide number that the presenter types before `Enter`.
export type State = {
  slide: number;
  step: number;
  view: View;
  blank: boolean;
  digits: string;
};

// `steps` holds the maximum step number of each slide, in slide order. The
// entry for slide 1 is at index 0.
export type Limits = {
  slides: number;
  steps: number[];
};

// The keys that move forward and back in the present view. A presentation
// remote sends `PageDown` and `PageUp`. The value `" "` is the space bar.
const FORWARD = ["j", "ArrowRight", "ArrowDown", "PageDown", " "];
const BACK = ["k", "ArrowLeft", "ArrowUp", "PageUp"];

// The first slide is slide 1, and the first step is step 1.
// `Expresso.Deck.number_slides/1` gives the same number to the identifier of
// each section.
export function initial(): State {
  return { slide: 1, step: 1, view: "present", blank: false, digits: "" };
}

// The maximum step number of a slide. A slide without an entry has one step.
export function maxStep(slide: number, limits: Limits): number {
  return limits.steps[slide - 1] ?? 1;
}

// Give the state after one key. A key that has no function gives the same
// state, and `main.ts` then lets the browser use the key.
//
// On a black screen, each key shows the slide again, and it does nothing more.
// The handout view knows only `j`, `k` and `p`. The browser keeps the other
// keys, so the arrow keys and the space bar scroll the pages. The speaker view
// knows the keys of the present view, but `p` has no function in it.
export function next(state: State, key: string, limits: Limits): State {
  if (state.blank) {
    return { ...state, blank: false };
  }
  if (state.view === "handout") {
    return handout(state, key, limits);
  }
  if (state.view === "speaker" && key === "p") {
    return state;
  }
  return present(state, key, limits);
}

// The step after the step of the state, or null at the last step of the last
// slide. The speaker view shows this step as the next step.
export function upcoming(state: State, limits: Limits): State | null {
  const after = forward(state, limits);
  return after === state ? null : after;
}

// The keys of the handout view. `j` and `k` change the state, and the view
// shows no change. `p` then shows that slide and step in the present view.
function handout(state: State, key: string, limits: Limits): State {
  if (key === "j") {
    return forward(state, limits);
  }
  if (key === "k") {
    return back(state, limits);
  }
  if (key === "p") {
    return { ...state, view: "present" };
  }
  return state;
}

// The keys of the present view. A digit adds to the slide number, and `Enter`
// goes to step 1 of that slide. Each other key removes the digits.
function present(state: State, key: string, limits: Limits): State {
  if (/^[0-9]$/.test(key)) {
    return { ...state, digits: state.digits + key };
  }
  if (key === "Enter") {
    return go(state, limits);
  }

  const cleared = state.digits === "" ? state : { ...state, digits: "" };
  if (FORWARD.includes(key)) {
    return forward(cleared, limits);
  }
  if (BACK.includes(key)) {
    return back(cleared, limits);
  }
  if (key === "Home") {
    return move(cleared, 1, limits);
  }
  if (key === "End") {
    return move(cleared, limits.slides, limits);
  }
  if (key === "b") {
    return { ...cleared, blank: true };
  }
  if (key === "p") {
    return { ...cleared, view: "handout" };
  }
  return cleared;
}

// Move to the next step, and to the first step of the next slide after the
// last step. A move past the last slide gives the same state.
function forward(state: State, limits: Limits): State {
  if (state.step < maxStep(state.slide, limits)) {
    return { ...state, step: state.step + 1 };
  }
  if (state.slide < limits.slides) {
    return { ...state, slide: state.slide + 1, step: 1 };
  }
  return state;
}

// Move to the previous step, and to the last step of the previous slide at
// the first step. A move past the first slide gives the same state.
function back(state: State, limits: Limits): State {
  if (state.step > 1) {
    return { ...state, step: state.step - 1 };
  }
  if (state.slide > 1) {
    const slide = state.slide - 1;
    return { ...state, slide, step: maxStep(slide, limits) };
  }
  return state;
}

// Go to step 1 of the slide that the digits give. A number that is not a
// slide removes the digits, and the slide stays.
function go(state: State, limits: Limits): State {
  if (state.digits === "") {
    return state;
  }
  const cleared = { ...state, digits: "" };
  return move(cleared, Number(state.digits), limits);
}

// Go to step 1 of a slide. A slide that the deck does not have, and the
// current position, give the same state.
function move(state: State, slide: number, limits: Limits): State {
  if (slide < 1 || slide > limits.slides) {
    return state;
  }
  if (slide === state.slide && state.step === 1) {
    return state;
  }
  return { ...state, slide, step: 1 };
}

// The fragment of the address for a state, such as `#4.2` for step 2 of
// slide 4. A reload of the document then shows the same step.
export function toHash(state: State): string {
  return `#${state.slide}.${state.step}`;
}

// Give the state for a fragment of the address. The fragment `#4` is step 1
// of slide 4. A fragment that gives no slide and step of the deck gives the
// same state.
export function fromHash(state: State, hash: string, limits: Limits): State {
  const match = /^#(\d+)(?:\.(\d+))?$/.exec(hash);
  if (match === null) {
    return state;
  }
  const slide = Number(match[1]);
  const step = match[2] === undefined ? 1 : Number(match[2]);
  return position(state, slide, step, false, limits);
}

// The message that one window of the presenter sends to the other window
// after each change. The speaker view and the present view then show the same
// step, and the key `b` in either window gives a black screen to the audience.
export type Message = {
  expresso: "position";
  slide: number;
  step: number;
  blank: boolean;
};

export function message(state: State): Message {
  const { slide, step, blank } = state;
  return { expresso: "position", slide, step, blank };
}

// Tell if data from the other window is a message of the presenter.
export function isMessage(data: unknown): data is Message {
  if (typeof data !== "object" || data === null) {
    return false;
  }
  const { expresso, slide, step, blank } = data as Record<string, unknown>;
  return (
    expresso === "position" &&
    Number.isInteger(slide) &&
    Number.isInteger(step) &&
    typeof blank === "boolean"
  );
}

// Give the state for a message from the other window. Data that is not a
// message, or that gives no slide and step of the deck, gives the same state.
export function follow(state: State, data: unknown, limits: Limits): State {
  if (!isMessage(data)) {
    return state;
  }
  return position(state, data.slide, data.step, data.blank, limits);
}

// Go to a slide, a step and a black screen. A slide and step that the deck
// does not have, and no change, give the same state.
function position(
  state: State,
  slide: number,
  step: number,
  blank: boolean,
  limits: Limits,
): State {
  if (slide < 1 || slide > limits.slides) {
    return state;
  }
  if (step < 1 || step > maxStep(slide, limits)) {
    return state;
  }
  if (slide === state.slide && step === state.step && blank === state.blank) {
    return state;
  }
  return { ...state, slide, step, blank, digits: "" };
}
