// The examination of a program of the presenter, for the tests.
//
// The script trusts the program, because the renderer writes the program and
// the script into the same document. The tests run each program that they make
// through `validate`. The function makes sure of each value, and it throws for
// a program that the script cannot run. The bundle does not hold this module.

import type {
  Attribute,
  Builtin,
  Command,
  Field,
  Mark,
  Mode,
  Program,
  Projections,
  Property,
} from "../src/program.ts";
import type { State, View } from "../src/state.ts";

const VIEWS: readonly View[] = ["present", "handout", "speaker"];
const BUILTINS: readonly Builtin[] = [
  "open_speaker",
  "fullscreen",
  "reset_timer",
];

// A program that is not valid is a defect of the renderer.
function invalid(): Error {
  return new Error("The program of the presenter is not valid");
}

function object(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw invalid();
  }
  return value as Record<string, unknown>;
}

function list(value: unknown): unknown[] {
  if (!Array.isArray(value)) {
    throw invalid();
  }
  return value;
}

function text(value: unknown): string {
  if (typeof value !== "string") {
    throw invalid();
  }
  return value;
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
  if (typeof data.name !== "string") {
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
    element: optionalList(data.element, state),
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

// A field of the state that holds a number, for a mark.
function numberField(value: unknown, state: State): Field {
  const name = field(value, state);
  if (typeof state[name] !== "number") {
    throw invalid();
  }
  return name;
}

function attribute(value: unknown, state: State): Attribute {
  const [name, target, flag] = list(value);
  if (typeof flag !== "boolean") {
    throw invalid();
  }
  return { field: field(name, state), name: text(target), flag };
}

function property(value: unknown): Property {
  const [name, entry] = list(value);
  if (entry !== "fraction" && entry !== "done") {
    throw invalid();
  }
  return { name: text(name), entry };
}

function mark(value: unknown, state: State): Mark {
  const [name, selector, key, values] = list(value);
  if (key !== "slide" && key !== "index") {
    throw invalid();
  }
  return {
    attribute: text(name),
    selector: text(selector),
    key,
    values: list(values).map((each) => {
      const [mark, target, offset] = list(each);
      return [text(mark), numberField(target, state), integer(offset)];
    }),
  };
}

function projections(value: unknown, state: State): Projections {
  const data = object(value);
  return {
    attributes: list(data.attributes).map((each) => attribute(each, state)),
    properties: list(data.properties).map(property),
    marks: list(data.marks).map((each) => mark(each, state)),
  };
}

// Read the JSON text of a program, and make sure of each value. A text that is
// not a program of the renderer throws an error.
export function validate(source: string): Program {
  const data = object(JSON.parse(source));
  const state = initialState(data.state);
  return {
    state,
    modes: list(data.modes).map((each) => mode(each, state)),
    project: projections(data.project, state),
  };
}

// Read the JSON text of the commands of an element, such as a page of the
// overview, and make sure of each value.
export function validateCommands(
  source: string,
  program: Program,
): readonly Command[] {
  return commandList(JSON.parse(source), program.state);
}
