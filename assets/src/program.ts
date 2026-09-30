// The program of the presenter.
//
// `Expresso.Presenter.Program` writes the program of the deck as JSON into the
// element `script#expresso-program`, and `dom.ts` reads it at load.
// `interpreter.ts` runs it. This module only reads the program and makes sure
// of each value. It does not touch the document.
//
// `Expresso.Presenter.Definition` tells what each mode and each command does.

import type { State, View } from "./state.ts";

// A field of the state.
export type Field = keyof State;

// A built-in function of the browser.
export type Builtin = "open_speaker" | "fullscreen" | "reset_timer";

// A part of the window for a click, and a direction of a swipe.
export type Region = "left_third" | "right";
export type Direction = "left" | "right";

export type Command =
  | readonly ["set", Field, State[Field]]
  | readonly ["toggle", Field]
  | readonly ["clear", Field]
  | readonly ["assign", "selected", readonly ["entry", "slide"]]
  | readonly ["append", "digits"]
  | readonly ["step", number]
  | readonly ["goto", number | null]
  | readonly ["goto_slide", "selected" | number]
  | readonly ["select", number]
  | readonly ["select_by", number]
  | readonly ["go_typed"]
  | readonly ["builtin", Builtin];

// A mode of the program. The interpreter uses the first mode whose `when`
// matches the state. `any` holds the commands of each event of the mode.
// `other` holds the commands of a key with no binding. `element` is true when a
// click on an element runs the commands of the element.
export type Mode = Readonly<{
  name: string;
  when: Readonly<Partial<State>>;
  any: readonly Command[] | null;
  other: readonly Command[] | null;
  element: boolean;
  keys: ReadonlyMap<string, readonly Command[]>;
  click: ReadonlyMap<string, readonly Command[]>;
  swipe: ReadonlyMap<string, readonly Command[]>;
}>;

export type Program = Readonly<{ state: State; modes: readonly Mode[] }>;

const VIEWS: readonly View[] = ["present", "handout", "speaker"];
const BUILTINS: readonly Builtin[] = [
  "open_speaker",
  "fullscreen",
  "reset_timer",
];

// A program that the renderer did not write is a defect of the renderer, so
// an error here is correct.
function invalid(): Error {
  return new Error("The program of the presenter is not valid");
}

function object(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw invalid();
  }
  return value as Record<string, unknown>;
}

function integer(value: unknown): number {
  if (!Number.isInteger(value)) {
    throw invalid();
  }
  return value as number;
}

// Make sure that a value has the type of a field. The field `view` takes only
// the name of a view.
function valueOf(field: Field, value: unknown, state: State): State[Field] {
  if (typeof value !== typeof state[field]) {
    throw invalid();
  }
  if (field === "view" && !VIEWS.includes(value as View)) {
    throw invalid();
  }
  return value as State[Field];
}

function field(value: unknown, state: State): Field {
  if (typeof value !== "string" || !(value in state)) {
    throw invalid();
  }
  return value as Field;
}

// Read one command. `state` holds the fields and the type of each field.
function command(value: unknown, state: State): Command {
  if (!Array.isArray(value)) {
    throw invalid();
  }
  const [name, first, second] = value as unknown[];
  switch (name) {
    case "set": {
      const target = field(first, state);
      return ["set", target, valueOf(target, second, state)];
    }
    case "toggle": {
      const target = field(first, state);
      if (typeof state[target] !== "boolean") {
        throw invalid();
      }
      return ["toggle", target];
    }
    case "clear":
      return ["clear", field(first, state)];
    case "assign":
      if (
        first !== "selected" ||
        !Array.isArray(second) ||
        second[0] !== "entry" ||
        second[1] !== "slide"
      ) {
        throw invalid();
      }
      return ["assign", "selected", ["entry", "slide"]];
    case "append":
      if (first !== "digits") {
        throw invalid();
      }
      return ["append", "digits"];
    case "step":
      return ["step", integer(first)];
    case "goto":
      return ["goto", first === null ? null : integer(first)];
    case "goto_slide":
      return ["goto_slide", first === "selected" ? "selected" : integer(first)];
    case "select":
      return ["select", integer(first)];
    case "select_by":
      return ["select_by", integer(first)];
    case "go_typed":
      return ["go_typed"];
    case "builtin":
      if (!BUILTINS.includes(first as Builtin)) {
        throw invalid();
      }
      return ["builtin", first as Builtin];
  }
  throw invalid();
}

function commandList(value: unknown, state: State): readonly Command[] {
  if (!Array.isArray(value)) {
    throw invalid();
  }
  return value.map((each) => command(each, state));
}

function optionalList(value: unknown, state: State): readonly Command[] | null {
  return value === null ? null : commandList(value, state);
}

// Read the pairs of events and commands into a map from each event to its
// commands.
function pairs(value: unknown, state: State): Map<string, readonly Command[]> {
  if (!Array.isArray(value)) {
    throw invalid();
  }
  const map = new Map<string, readonly Command[]>();
  for (const pair of value) {
    if (!Array.isArray(pair) || !Array.isArray(pair[0])) {
      throw invalid();
    }
    const commands = commandList(pair[1], state);
    for (const event of pair[0] as unknown[]) {
      if (typeof event !== "string") {
        throw invalid();
      }
      map.set(event, commands);
    }
  }
  return map;
}

function mode(value: unknown, state: State): Mode {
  const data = object(value);
  if (typeof data.name !== "string" || typeof data.element !== "boolean") {
    throw invalid();
  }
  const when: Partial<Record<Field, State[Field]>> = {};
  for (const [key, each] of Object.entries(object(data.when))) {
    const target = field(key, state);
    when[target] = valueOf(target, each, state);
  }
  return {
    name: data.name,
    when: when as Partial<State>,
    any: optionalList(data.any, state),
    other: optionalList(data.other, state),
    element: data.element,
    keys: pairs(data.keys, state),
    click: pairs(data.click, state),
    swipe: pairs(data.swipe, state),
  };
}

// The first state. It holds exactly the fields of `State`, each with its type.
function initialState(value: unknown): State {
  const data = object(value);
  const types: Record<Field, string> = {
    index: "number",
    view: "string",
    blank: "boolean",
    digits: "string",
    help: "boolean",
    progress: "boolean",
    every: "boolean",
    overview: "boolean",
    selected: "number",
  };
  const keys = Object.keys(data);
  if (keys.length !== Object.keys(types).length) {
    throw invalid();
  }
  for (const key of keys) {
    if (!(key in types) || typeof data[key] !== types[key as Field]) {
      throw invalid();
    }
  }
  if (!VIEWS.includes(data.view as View)) {
    throw invalid();
  }
  return data as State;
}

// Read the JSON text of the program. A text that is not a program of the
// renderer throws an error.
export function parse(text: string): Program {
  const data = object(JSON.parse(text));
  const state = initialState(data.state);
  if (!Array.isArray(data.modes)) {
    throw invalid();
  }
  return { state, modes: data.modes.map((each) => mode(each, state)) };
}

// Read the JSON text of the commands of an element, such as a page of the
// overview. The renderer writes them in the attribute `data-commands`.
export function commands(text: string, program: Program): readonly Command[] {
  return commandList(JSON.parse(text), program.state);
}
