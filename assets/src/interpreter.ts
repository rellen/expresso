// The interpreter of the presenter program.
//
// `run` applies one event to a state, with the program of the deck. It does
// these steps:
//
// 1. It finds the first mode whose condition the state matches.
// 2. It finds the commands of the event in that mode.
// 3. It applies the commands to the state, one after the other.
//
// `Expresso.Presenter.Interpreter` is the reference interpreter in Elixir, and
// the tests run the two interpreters on the same fixtures. The functions of this
// module do not touch the document.
//
// The fragment of the address and the messages between the windows do not go
// through the modes. `fromHash` and `follow` go to a slide and a step directly.

import { indexOf } from "./deck.ts";
import type { Deck, Kind } from "./deck.ts";
import type {
  Builtin,
  Command,
  Direction,
  Field,
  Mode,
  Program,
  Region,
} from "./program.ts";
import { FIELDS } from "./schema.ts";
import { current, isMessage } from "./state.ts";
import type { State } from "./state.ts";

// A key, a click or a swipe. A click holds the commands of the element under
// the click, such as a page of the overview, or `null`.
export type Event =
  | Readonly<{ kind: "key"; key: string }>
  | Readonly<{
      kind: "click";
      region: Region;
      element: readonly Command[] | null;
    }>
  | Readonly<{ kind: "swipe"; direction: Direction }>;

// The state after an event, and the built-in functions that the event calls.
// A state with no change is the same object as the state before the event.
export type Result = Readonly<{ state: State; effects: readonly Builtin[] }>;

function same(a: State, b: State): boolean {
  return FIELDS.every((field) => a[field] === b[field]);
}

function matches(mode: Mode, state: State): boolean {
  return Object.entries(mode.when).every(
    ([field, value]) => state[field as Field] === value,
  );
}

// The first mode whose condition the state matches.
export function modeOf(program: Program, state: State): Mode | undefined {
  return program.modes.find((mode) => matches(mode, state));
}

// The name of the mode under the list of keys. The list of keys shows the rows
// of this mode.
export function helpMode(program: Program, state: State): string | undefined {
  return modeOf(program, { ...state, blank: false, help: false })?.name;
}

function commandsOf(mode: Mode, event: Event): readonly Command[] {
  if (mode.any !== null) {
    return mode.any;
  }
  switch (event.kind) {
    case "key":
      return mode.keys.get(event.key) ?? mode.other ?? [];
    case "click":
      if (mode.element !== null && event.element !== null) {
        return [...mode.element, ...event.element];
      }
      return mode.click.get(event.region) ?? [];
    case "swipe":
      return mode.swipe.get(event.direction) ?? [];
  }
}

// Apply one event to a state.
export function run(
  program: Program,
  deck: Deck,
  state: State,
  event: Event,
): Result {
  const mode = modeOf(program, state);
  if (mode === undefined) {
    return { state, effects: [] };
  }
  let after = state;
  const effects: Builtin[] = [];
  for (const each of commandsOf(mode, event)) {
    if (each[0] === "builtin") {
      effects.push(each[1]);
    } else {
      after = apply(program, deck, after, each, event);
    }
  }
  after = reset(program, state, after);
  return { state: same(state, after) ? state : after, effects };
}

// A change of the step gives each field of the option `reset` its first value.
// Thus the key `d`, which turns off the dimming of code, holds only for the
// step where the presenter pressed it.
function reset(program: Program, before: State, after: State): State {
  if (after.index === before.index) {
    return after;
  }
  const first = Object.fromEntries(
    program.reset.map((field) => [field, program.state[field]]),
  );
  return { ...after, ...first };
}

// Return true when `main.ts` must stop the default operation of the browser:
// the state changed, or the event called a built-in function.
export function prevented(before: State, result: Result): boolean {
  return result.state !== before || result.effects.length > 0;
}

function apply(
  program: Program,
  deck: Deck,
  state: State,
  command: Command,
  event: Event,
): State {
  switch (command[0]) {
    case "set":
      return { ...state, [command[1]]: command[2] };
    case "toggle":
      return { ...state, [command[1]]: !state[command[1]] };
    case "clear":
      return { ...state, [command[1]]: program.state[command[1]] };
    case "assign":
      return { ...state, selected: slideOf(state, deck) };
    case "append":
      return event.kind === "key"
        ? { ...state, digits: state.digits + event.key }
        : state;
    case "step":
      return goto(state, state.index + command[1], deck);
    case "goto":
      return command[1] === null ? state : goto(state, command[1], deck);
    case "goto_slide":
      return gotoSlide(
        state,
        command[1] === "selected" ? state.selected : command[1],
        deck,
      );
    case "select":
      return select(state, command[1], deck);
    case "select_by":
      return select(state, state.selected + command[1], deck);
    case "go_typed":
      return state.digits === ""
        ? state
        : gotoSlide({ ...state, digits: "" }, Number(state.digits), deck);
    case "builtin":
      return state;
    default: {
      // The type check finds each command that has no branch. The program
      // comes from the renderer with no examination, so a command that the
      // script does not know stops the script at once.
      const unknown: never = command;
      throw new Error(`An unknown command: ${JSON.stringify(unknown)}`);
    }
  }
}

// A move past the first step or the last step makes no change.
function goto(state: State, index: number, deck: Deck): State {
  if (index < 0 || index >= deck.steps.length) {
    return state;
  }
  return { ...state, index };
}

function gotoSlide(state: State, slide: number, deck: Deck): State {
  const index = indexOf(deck, slide, 1);
  return index === undefined ? state : { ...state, index };
}

// A slide outside the deck makes no change.
function select(state: State, slide: number, deck: Deck): State {
  if (slide < 1 || slide > deck.slides.length) {
    return state;
  }
  return { ...state, selected: slide };
}

// The number of the current slide. A deck with no slide returns 1.
function slideOf(state: State, deck: Deck): number {
  return current(state, deck)?.slide ?? 1;
}

// Go to a slide and a step, and set the fields of a fragment or of a message.
// A change of the step resets the fields of the option `reset` before the
// fields apply. A slide and a step that the deck does not have make no change,
// and the current position with the same fields also makes no change.
function position(
  program: Program,
  state: State,
  slide: number,
  step: number,
  fields: Partial<State>,
  deck: Deck,
): State {
  const index = indexOf(deck, slide, step);
  if (index === undefined) {
    return state;
  }
  const moved = { ...reset(program, state, { ...state, index }), ...fields };
  return same(state, moved) ? state : { ...moved, digits: "" };
}

// The fragment of the address for a state, such as `#4.2` for step 2 of slide
// 4. A reload of the document then shows the same step. A deck with no slide
// returns `#1.1`.
export function toHash(state: State, deck: Deck): string {
  const entry = current(state, deck);
  return `#${entry?.slide ?? 1}.${entry?.step ?? 1}`;
}

// Go to the slide and the step of a fragment. The fragment `#4` is step 1 of
// slide 4, and a fragment removes a black screen. A fragment with no slide and
// step of the deck makes no change.
export function fromHash(
  program: Program,
  state: State,
  hash: string,
  deck: Deck,
): State {
  const match = /^#(\d+)(?:\.(\d+))?$/.exec(hash);
  if (match === null) {
    return state;
  }
  const slide = Number(match[1]);
  const step = match[2] === undefined ? 1 : Number(match[2]);
  return position(program, state, slide, step, { blank: false }, deck);
}

// Go to the position of a message from the other window, and take its fields
// of the option `sync`. Data that is not a message, or that has no slide and
// step of the deck, makes no change. The other fields of the message have no
// effect.
export function follow(
  program: Program,
  state: State,
  data: unknown,
  deck: Deck,
): State {
  if (!isMessage(data)) {
    return state;
  }
  const fields = Object.fromEntries(
    program.sync.flatMap((field) =>
      field in data.fields ? [[field, data.fields[field]]] : [],
    ),
  );
  return position(program, state, data.slide, data.step, fields, deck);
}

// The state at the next step, or null at the last step of the deck. The
// speaker view shows this step as the next step.
export function upcoming(state: State, deck: Deck): State | null {
  const after = goto(state, state.index + 1, deck);
  return after === state ? null : after;
}

// A move to a slide with a higher number goes forward. `slide` and `zoom` use
// the direction, and `fade` does not.
export type Transition = Readonly<{
  kind: Kind;
  direction: "forward" | "back";
}>;

// The transition between two states, or null for no transition. Only a move to
// a different slide in the present view has a transition. A change of the step,
// a black screen, the overview and the list of keys have no transition.
//
// A transition belongs to the border between two slides, so in the two
// directions the kind comes from the slide with the higher number. The style
// sheet plays a move back in reverse. The kind `none` has no transition.
export function transition(
  before: State,
  after: State,
  deck: Deck,
): Transition | null {
  const quiet = (state: State) =>
    state.view !== "present" || state.blank || state.overview || state.help;
  const from = slideOf(before, deck);
  const to = slideOf(after, deck);
  if (from === to || quiet(before) || quiet(after)) {
    return null;
  }
  const kind: Kind = deck.slides[Math.max(from, to) - 1]?.transition ?? "fade";
  if (kind === "none") {
    return null;
  }
  return { kind, direction: to > from ? "forward" : "back" };
}
