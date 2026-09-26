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
// the `handout` option of each slide selects. `overview` is true while the
// present view or the speaker view shows a grid of the slides. `selected` is
// the number of the selected slide in that grid. A message does not hold the
// overview, so the overview shows only in the window that opens it.
export type State = {
  slide: number;
  step: number;
  view: View;
  blank: boolean;
  digits: string;
  help: boolean;
  progress: boolean;
  every: boolean;
  overview: boolean;
  selected: number;
};

// The set of keys that operate. The overview has its own set of keys in each
// view that shows it.
export type Mode = View | "overview";

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
  | "overview"
  | "up"
  | "down"
  | "pick"
  | "help";

// One or more keys, their function, the views that know them, and the text
// of the list of keys. `label` replaces the names of the keys in that list. A
// binding with no key is a row for a click, a tap or a swipe: `point` gives
// its function, and `binding` does not find it.
export type Binding = {
  keys: string[];
  action: Action;
  views: Mode[];
  text: string;
  label?: string;
};

const SHOWING: Mode[] = ["present", "speaker"];
const OVERVIEW: Mode[] = ["overview"];
const DIGITS = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];

// The keys of the presenter. `next` and the list of keys read this table, so
// the list shows each key that operates, and no other key. A presentation
// remote sends `PageDown` and `PageUp`. The value `" "` is the space bar. The
// handout view knows only `j`, `k`, `p`, `a` and `?`, so the browser keeps the
// other keys, and the arrow keys and the space bar scroll the pages. The rows
// of the overview are last, because the overview uses the same keys with
// other functions.
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
    keys: ["o"],
    action: "overview",
    views: SHOWING,
    text: "Overview of the slides. Only this window shows it.",
  },
  {
    keys: ["?"],
    action: "help",
    views: ["present", "handout", "speaker", "overview"],
    text: "This list of keys. The next key closes it.",
  },
  {
    keys: ["j", "ArrowRight", "PageDown", " "],
    action: "forward",
    views: OVERVIEW,
    text: "Select the next slide",
  },
  {
    keys: ["k", "ArrowLeft", "PageUp"],
    action: "back",
    views: OVERVIEW,
    text: "Select the previous slide",
  },
  {
    keys: ["ArrowDown"],
    action: "down",
    views: OVERVIEW,
    text: "Select the slide below",
  },
  {
    keys: ["ArrowUp"],
    action: "up",
    views: OVERVIEW,
    text: "Select the slide above",
  },
  {
    keys: ["Home"],
    action: "first",
    views: OVERVIEW,
    text: "Select the first slide",
  },
  {
    keys: ["End"],
    action: "last",
    views: OVERVIEW,
    text: "Select the last slide",
  },
  {
    keys: ["Enter"],
    action: "pick",
    views: OVERVIEW,
    text: "Step 1 of the selected slide",
  },
  {
    keys: [],
    action: "pick",
    views: OVERVIEW,
    text: "Step 1 of that slide",
    label: "Click or tap a slide",
  },
  {
    keys: ["o", "Escape"],
    action: "overview",
    views: OVERVIEW,
    text: "Close the overview. The step does not change.",
  },
];

// The mode of a state. While the overview shows, the mode is the overview.
// At other times, the mode is the view.
export function mode(state: State): Mode {
  return state.overview ? "overview" : state.view;
}

// The binding of a key in the mode of the state, or undefined for a key that
// the mode does not know.
export function binding(state: State, key: string): Binding | undefined {
  const current = mode(state);
  return BINDINGS.find(
    (each) => each.views.includes(current) && each.keys.includes(key),
  );
}

// The transition from one slide to the next in the present view. The renderer
// writes one kind on each slide, from the option of the slide or of the deck.
export type Kind = "none" | "fade" | "slide" | "zoom";

export const KINDS: Kind[] = ["none", "fade", "slide", "zoom"];

// A move to a slide with a higher number goes forward. `slide` and `zoom`
// use the direction, and `fade` does not.
export type Transition = { kind: Kind; direction: "forward" | "back" };

// Give the transition of a change of state, or null for no transition. Only
// a move to a different slide in the present view has a transition. A change
// of the step keeps the transitions of the overlays. A black screen, the
// overview and the list of keys have no transition.
//
// A transition belongs to the border between two slides. A move forward uses
// the kind of the slide that it goes to. A move back uses the kind of the
// slide that it leaves, and the style sheet plays it in reverse. For this
// reason, the kind of the slide with the higher number gives the kind, in the
// two directions. The kind `none` gives no transition. `kinds` holds the kind of
// each slide, in slide order, and a slide without a kind fades.
export function transition(
  before: State,
  after: State,
  kinds: Kind[],
): Transition | null {
  const quiet = (state: State) =>
    state.view !== "present" || state.blank || state.overview || state.help;
  if (before.slide === after.slide || quiet(before) || quiet(after)) {
    return null;
  }
  const kind = kinds[Math.max(before.slide, after.slide) - 1] ?? "fade";
  if (kind === "none") {
    return null;
  }
  return {
    kind,
    direction: after.slide > before.slide ? "forward" : "back",
  };
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
    overview: false,
    selected: 1,
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
  if (state.overview) {
    return overview(state, action, limits);
  }
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
    case "overview":
      return { ...cleared, overview: true, selected: cleared.slide };
    default:
      return cleared;
  }
}

// The number of columns of the overview: the square root of the number of
// slides, or the next larger integer. The number of rows is then not more than
// the number of columns, and each slide fits in the window.
export function columns(slides: number): number {
  return Math.max(1, Math.ceil(Math.sqrt(slides)));
}

// Give the state after a key of the overview. A key selects a different
// slide. A key that selects a slide outside the deck has no effect. `pick`
// goes to step 1 of the selected slide. `overview` closes the overview, and
// the step does not change.
function overview(
  state: State,
  action: Action | undefined,
  limits: Limits,
): State {
  const width = columns(limits.slides);
  switch (action) {
    case "forward":
      return select(state, state.selected + 1, limits);
    case "back":
      return select(state, state.selected - 1, limits);
    case "down":
      return select(state, state.selected + width, limits);
    case "up":
      return select(state, state.selected - width, limits);
    case "first":
      return select(state, 1, limits);
    case "last":
      return select(state, limits.slides, limits);
    case "pick":
      return choose(state, state.selected, limits);
    case "overview":
      return { ...state, overview: false };
    case "help":
      return { ...state, help: true };
    default:
      return state;
  }
}

function select(state: State, slide: number, limits: Limits): State {
  if (slide < 1 || slide > limits.slides || slide === state.selected) {
    return state;
  }
  return { ...state, selected: slide };
}

// Give the state that closes the overview and goes to step 1 of a slide. A
// click on a slide of the overview and the key `Enter` use this function. For
// a number that is not a slide, the function only closes the overview.
export function choose(state: State, slide: number, limits: Limits): State {
  return move({ ...state, overview: false }, slide, limits);
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
// handout view scrolls with a finger, so there it has no other function. In
// the overview, `choose` gives the function of a click on a slide.
export function point(state: State, pointer: Pointer, limits: Limits): State {
  const shown = close(state);
  if (shown !== state || state.view === "handout" || state.overview) {
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
  const [before, total] = count(state, limits);
  if (total <= 1) {
    return 0;
  }
  return before / (total - 1);
}

// The part of the deck that is done at the start of the step of the state,
// from 0 at the first step. Each step of each slide counts one time. The last
// step also has its part, so the value at the last step is less than 1.
// `fraction` is 1 there. The speaker view compares this part with the time of
// the talk. A deck with no step gives 0.
export function done(state: State, limits: Limits): number {
  const [before, total] = count(state, limits);
  return total === 0 ? 0 : before / total;
}

// The number of steps before the step of the state, and the number of steps
// of the deck.
function count(state: State, limits: Limits): [number, number] {
  let total = 0;
  let before = 0;
  for (let slide = 1; slide <= limits.slides; slide++) {
    const steps = maxStep(slide, limits);
    total += steps;
    if (slide < state.slide) {
      before += steps;
    }
  }
  return [before + state.step - 1, total];
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
