// The program of the presenter.
//
// `Expresso.Presenter.Program` writes the program of the deck as JSON into the
// element `script#expresso-program`, and `dom.ts` reads it at load.
// `interpreter.ts` runs it. This module only reads the program, and it does not
// touch the document.
//
// The renderer writes the program and this script into the same document, so
// the script trusts the program and does not examine it. The tests examine
// each program that they make with `assets/test/validate.ts`, and the Spark
// verifiers examine the definition when it compiles.
//
// `Expresso.Presenter.Definition` tells what each mode and each command does.

import type {
  Command,
  Commands,
  Field,
  WrittenMode,
  WrittenProgram,
} from "./schema.ts";

// `schema.ts` declares the types of the values that the renderer writes.
export type { Builtin, Command, Direction, Field, Region } from "./schema.ts";

// A mode of the program. The interpreter uses the first mode whose `when`
// matches the state. `any` holds the commands of each event of the mode.
// `other` holds the commands of a key with no binding. `element` holds the
// commands that go in front of the commands of an element under a click, or
// `null` when the mode does not run the commands of an element.
export type Mode = Readonly<{
  name: string;
  when: WrittenMode["when"];
  any: readonly Command[] | null;
  other: readonly Command[] | null;
  element: readonly Command[] | null;
  keys: ReadonlyMap<string, readonly Command[]>;
  click: ReadonlyMap<string, readonly Command[]>;
  swipe: ReadonlyMap<string, readonly Command[]>;
}>;

// A projection writes a part of the state to the document, and
// `Expresso.Presenter.Projection` tells what each kind does. An attribute
// writes a field on the `body`, and with `flag` it is present only while the
// field is true. A property writes a value of the current entry into a custom
// property of the `body`. A mark writes an attribute on each element of a
// selector whose `data-slide` or `data-index` agrees with a field plus an
// offset.
export type Attribute = Readonly<{ field: Field; name: string; flag: boolean }>;
export type Property = Readonly<{ name: string; entry: "fraction" | "done" }>;
export type Mark = Readonly<{
  attribute: string;
  selector: string;
  key: "slide" | "index";
  values: readonly (readonly [string, Field, number])[];
}>;
export type Projections = Readonly<{
  attributes: readonly Attribute[];
  properties: readonly Property[];
  marks: readonly Mark[];
}>;

export type Program = Readonly<{
  state: WrittenProgram["state"];
  modes: readonly Mode[];
  project: Projections;
}>;

// The pairs of events and commands of a mode, as the renderer writes them. Each
// pair holds each event that has the same commands.
type Pairs = WrittenMode["keys" | "click" | "swipe"];

function map(pairs: Pairs): ReadonlyMap<string, readonly Command[]> {
  return new Map(
    pairs.flatMap(([events, commands]) =>
      events.map((event) => [event, commands] as const),
    ),
  );
}

// Make maps of the pairs and objects of the projections. `parse` reads the
// text, and the tests read a program that `decodeWrittenProgram` returns.
export function fromWritten({
  state,
  modes,
  project,
}: WrittenProgram): Program {
  return {
    state,
    modes: modes.map((mode) => ({
      ...mode,
      keys: map(mode.keys),
      click: map(mode.click),
      swipe: map(mode.swipe),
    })),
    project: {
      attributes: project.attributes.map(([field, name, flag]) => ({
        field,
        name,
        flag,
      })),
      properties: project.properties.map(([name, entry]) => ({ name, entry })),
      marks: project.marks.map(([attribute, selector, key, values]) => ({
        attribute,
        selector,
        key,
        values,
      })),
    },
  };
}

// Read the JSON text of the program.
export function parse(source: string): Program {
  return fromWritten(JSON.parse(source));
}

// Read the JSON text of the commands of an element, such as a page of the
// overview. The renderer writes them in the attribute `data-commands`.
export function commands(source: string): Commands {
  return JSON.parse(source);
}
