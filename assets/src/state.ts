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
// `help` is true while the view shows the list of its keys. `progress` is
// true while the present view shows the progress bar. `every` is true while
// the handout view, and a print, show every step and not only the steps that
// the `handout` option of each slide selects.
export type State = {
  slide: number;
  step: number;
  view: View;
  blank: boolean;
  digits: string;
  help: boolean;
  progress: boolean;
  every: boolean;
};

// `steps` holds the maximum step number of each slide, in slide order. The
// entry for slide 1 is at index 0.
export type Limits = {
  slides: number;
  steps: number[];
};

// The function of a key. `main.ts` does the functions `speaker`, `reset` and
// `fullscreen`, because they do not change the state.
export type Action =
  | "forward"
  | "back"
  | "first"
  | "last"
  | "digit"
  | "go"
  | "blank"
  | "handout"
  | "present"
  | "speaker"
  | "reset"
  | "fullscreen"
  | "progress"
  | "every"
  | "help";

// One or more keys, their function, the views that know them, and the text
// of the list of keys. `label` replaces the names of the keys in that list. A
// binding with no key is a row for a click, a tap or a swipe: `point` gives
// its function, and `binding` does not find it.
export type Binding = {
  keys: string[];
  action: Action;
  views: View[];
  text: string;
  label?: string;
};

const SHOWING: View[] = ["present", "speaker"];
const DIGITS = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];

// The keys of the presenter. `next` and the list of keys read this table, so
// the list shows each key that operates, and no other key. A presentation
// remote sends `PageDown` and `PageUp`. The value `" "` is the space bar. The
// handout view knows only `j`, `k`, `p`, `a` and `?`, so the browser keeps the
// other keys, and the arrow keys and the space bar scroll the pages.
export const BINDINGS: Binding[] = [
  {
    keys: ["j", "ArrowRight", "ArrowDown", "PageDown", " "],
    action: "forward",
    views: SHOWING,
    text: "Next step, or the first step of the next slide",
  },
  {
    keys: ["k", "ArrowLeft", "ArrowUp", "PageUp"],
    action: "back",
    views: SHOWING,
    text: "Previous step, or the last step of the previous slide",
  },
  {
    keys: ["j"],
    action: "forward",
    views: ["handout"],
    text: "Next step. The present view then shows it.",
  },
  {
    keys: ["k"],
    action: "back",
    views: ["handout"],
    text: "Previous step. The present view then shows it.",
  },
  { keys: ["Home"], action: "first", views: SHOWING, text: "First slide" },
  {
    keys: ["End"],
    action: "last",
    views: SHOWING,
    text: "Step 1 of the last slide",
  },
  {
    keys: DIGITS,
    action: "digit",
    views: SHOWING,
    text: "Type a slide number",
    label: "0 to 9",
  },
  {
    keys: ["Enter"],
    action: "go",
    views: SHOWING,
    text: "Step 1 of the slide that you typed",
  },
  {
    keys: ["b"],
    action: "blank",
    views: SHOWING,
    text: "Black screen. The next key shows the slide again.",
  },
  {
    keys: ["p"],
    action: "handout",
    views: ["present"],
    text: "Handout view",
  },
  {
    keys: ["p"],
    action: "present",
    views: ["handout"],
    text: "Present view",
  },
  {
    keys: ["s"],
    action: "speaker",
    views: ["present"],
    text: "Speaker view, in a second window",
  },
  {
    keys: ["r"],
    action: "reset",
    views: ["speaker"],
    text: "Set the timer to 0:00",
  },
  {
    keys: ["f"],
    action: "fullscreen",
    views: SHOWING,
    text: "Full screen on or off",
  },
  {
    keys: ["g"],
    action: "progress",
    views: ["present"],
    text: "Progress bar on or off",
  },
  {
    keys: ["a"],
    action: "every",
    views: ["handout"],
    text: "Every step, or the steps of the handout option. A print shows the same.",
  },
  {
    keys: [],
    action: "forward",
    views: SHOWING,
    text: "Next step",
    label: "Click or tap the right two thirds, or swipe left",
  },
  {
    keys: [],
    action: "back",
    views: SHOWING,
    text: "Previous step",
    label: "Click or tap the left third, or swipe right",
  },
  {
    keys: ["?"],
    action: "help",
    views: ["present", "handout", "speaker"],
    text: "This list of keys. The next key closes it.",
  },
];

// The binding of a key in the view of the state, or undefined for a key that
// the view does not know.
export function binding(state: State, key: string): Binding | undefined {
  return BINDINGS.find(
    (each) => each.views.includes(state.view) && each.keys.includes(key),
  );
}

// The first slide is slide 1, and the first step is step 1.
// `Expresso.Deck.number_slides/1` gives the same number to the identifier of
// each section.
export function initial(): State {
  return {
    slide: 1,
    step: 1,
    view: "present",
    blank: false,
    digits: "",
    help: false,
    progress: true,
    every: false,
  };
}

// The maximum step number of a slide. A slide without an entry has one step.
export function maxStep(slide: number, limits: Limits): number {
  return limits.steps[slide - 1] ?? 1;
}

// Give the state after one key. A key that has no function gives the same
// state, and `main.ts` then lets the browser use the key.
//
// On a black screen or on the list of keys, each key closes it, and it does
// nothing more. A digit adds to the slide number, and `Enter` goes to step 1
// of that slide. Each other key removes the digits.
export function next(state: State, key: string, limits: Limits): State {
  const shown = close(state);
  if (shown !== state) {
    return shown;
  }

  const action = binding(state, key)?.action;
  if (action === "digit") {
    return { ...state, digits: state.digits + key };
  }
  if (action === "go") {
    return go(state, limits);
  }

  const cleared = state.digits === "" ? state : { ...state, digits: "" };
  switch (action) {
    case "forward":
      return forward(cleared, limits);
    case "back":
      return back(cleared, limits);
    case "first":
      return move(cleared, 1, limits);
    case "last":
      return move(cleared, limits.slides, limits);
    case "blank":
      return { ...cleared, blank: true };
    case "handout":
      return { ...cleared, view: "handout" };
    case "present":
      return { ...cleared, view: "present" };
    case "help":
      return { ...cleared, help: true };
    case "progress":
      return { ...cleared, progress: !cleared.progress };
    case "every":
      return { ...cleared, every: !cleared.every };
    default:
      return cleared;
  }
}

// The state with no black screen and no list of keys. A state with neither
// gives the same state.
function close(state: State): State {
  if (state.blank) {
    return { ...state, blank: false };
  }
  if (state.help) {
    return { ...state, help: false };
  }
  return state;
}

// A click, a tap or a swipe moves one step forward or one step back.
export type Pointer = "forward" | "back";

// The function of a click or a tap at `x` pixels from the left edge of a
// window of `width` pixels. The left third goes back, because a person
// clicks to go forward more frequently than to go back.
export function side(x: number, width: number): Pointer {
  return x < width / 3 ? "back" : "forward";
}

// The minimum horizontal distance of a swipe, in pixels.
export const SWIPE = 50;

// The function of a movement of a finger across the screen. A swipe to the
// left goes forward, as on a page of a book. A short movement or a movement
// that is more vertical than horizontal has no function.
export function swipe(dx: number, dy: number): Pointer | undefined {
  if (Math.abs(dx) < SWIPE || Math.abs(dx) <= Math.abs(dy)) {
    return undefined;
  }
  return dx < 0 ? "forward" : "back";
}

// Give the state after a click, a tap or a swipe. As a key does, it first
// closes a black screen or the list of keys, and it does nothing more. The
// handout view scrolls with a finger, so there it has no other function.
export function point(state: State, pointer: Pointer, limits: Limits): State {
  const shown = close(state);
  if (shown !== state || state.view === "handout") {
    return shown;
  }
  const cleared = state.digits === "" ? state : { ...state, digits: "" };
  return pointer === "forward"
    ? forward(cleared, limits)
    : back(cleared, limits);
}

// The part of the deck before the step of the state, from 0 at the first step
// of the first slide to 1 at the last step of the last slide. Each step of
// each slide counts one time. A deck of one step or no step gives 0.
export function fraction(state: State, limits: Limits): number {
  let total = 0;
  let before = 0;
  for (let slide = 1; slide <= limits.slides; slide++) {
    const steps = maxStep(slide, limits);
    total += steps;
    if (slide < state.slide) {
      before += steps;
    }
  }
  if (total <= 1) {
    return 0;
  }
  return (before + state.step - 1) / (total - 1);
}

// The step after the step of the state, or null at the last step of the last
// slide. The speaker view shows this step as the next step.
export function upcoming(state: State, limits: Limits): State | null {
  const after = forward(state, limits);
  return after === state ? null : after;
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
// after each change of its own. The speaker view and the present view then show
// the same step, and the key `b` in either window gives a black screen to the
// audience.
//
// `time` is the time of the change in milliseconds. A window does not send a
// position from the other window back, and it ignores a message that is older
// than its own state. Two keys that come faster than a message can then give
// no loop: before this rule, the echo of the first key came back after the
// second key, and the two windows sent the two positions to each other with
// no end.
export type Message = {
  expresso: "position";
  slide: number;
  step: number;
  blank: boolean;
  time: number;
};

export function message(state: State, time: number): Message {
  const { slide, step, blank } = state;
  return { expresso: "position", slide, step, blank, time };
}

// The time of a change of this window: the clock, or one more than the time of
// the state before it, so that the times of one window always increase. The two
// windows read the same clock, so the time orders the changes of both.
export function stamp(last: number, now: number): number {
  return Math.max(now, last + 1);
}

// Tell if a window takes a message with the time `incoming`, when its own state
// has the time `own`. A newer message wins. At the same time, the speaker view
// takes the state of the present view, and the present view keeps its own, so
// the two windows always end at the same state.
export function accepts(
  own: number,
  incoming: number,
  speaker: boolean,
): boolean {
  return incoming > own || (incoming === own && speaker);
}

// Tell if data from the other window is a message of the presenter.
export function isMessage(data: unknown): data is Message {
  if (typeof data !== "object" || data === null) {
    return false;
  }
  const { expresso, slide, step, blank, time } = data as Record<
    string,
    unknown
  >;
  return (
    expresso === "position" &&
    Number.isInteger(slide) &&
    Number.isInteger(step) &&
    typeof blank === "boolean" &&
    Number.isFinite(time)
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
