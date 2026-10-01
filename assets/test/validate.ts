// The examination of a program of the presenter and of a list of the steps,
// for the tests.
//
// The script trusts the program and the list, because the renderer writes them
// and the script into the same document. The tests run each program that they
// make through `validate`, and each list through `validateDeck`. The decoders
// of `schema.ts` make sure of each value, and they throw a `DecodeError` for a
// program or a list that the script cannot run. `Expresso.Presenter.Schema`
// declares the forms. The bundle does not hold these functions.

import { is } from "../src/decode.ts";
import { fromWritten as deckOf } from "../src/deck.ts";
import type { Deck } from "../src/deck.ts";
import { fromWritten as programOf } from "../src/program.ts";
import type { Program } from "../src/program.ts";
import {
  decodeCommands,
  decodeKind,
  decodeWrittenDeck,
  decodeWrittenProgram,
} from "../src/schema.ts";
import type { Commands, Kind } from "../src/schema.ts";

// Read the JSON text of a program, and make sure of each value.
export function validate(source: string): Program {
  return programOf(decodeWrittenProgram(JSON.parse(source)));
}

// Read the JSON text of the commands of an element, such as a page of the
// overview, and make sure of each value.
export function validateCommands(source: string): Commands {
  return decodeCommands(JSON.parse(source));
}

// Read the JSON text of a list of the steps, and make sure of each value.
export function validateDeck(text: string): Deck {
  return deckOf(decodeWrittenDeck(JSON.parse(text)));
}

// Tell if a value is a kind of transition.
export function isKind(value: unknown): value is Kind {
  return is(decodeKind, value);
}
