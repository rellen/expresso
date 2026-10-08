// The messages between the windows, for the tests.
//
// `position` makes a message from the keys that a test gives. Each other key
// takes the value of the first state of the program: slide 1, step 1, the
// first value of each field of the option `sync`, no variant and the time 1.
// A new field of `sync` thus changes no test that does not use it.

import type { Message, Scheme, State } from "../src/schema.ts";
import { load, raw } from "./fixtures.ts";

// Each deck of the fixture file has the same `sync` and the same first state of
// these fields.
const { program } = load(Object.keys(raw.decks)[0] ?? "");

export type Given = Partial<{
  slide: number;
  step: number;
  scheme: Scheme;
  time: number;
}> &
  Partial<State>;

export function position({
  slide = 1,
  step = 1,
  scheme = null,
  time = 1,
  ...fields
}: Given = {}): Message {
  for (const field of Object.keys(fields)) {
    if (!(program.sync as readonly string[]).includes(field)) {
      throw new Error(`A message does not hold the field "${field}".`);
    }
  }
  return {
    expresso: "position",
    slide,
    step,
    fields: Object.fromEntries(
      program.sync.map((field) => [
        field,
        fields[field] ?? program.state[field],
      ]),
    ),
    scheme,
    time,
  };
}
