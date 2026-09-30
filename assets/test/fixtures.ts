// The fixtures of the tests of the interpreter and of `main.ts`.
//
// The programs come from Elixir, and Node cannot run Elixir. Therefore Git
// holds them in `fixtures/presenter.json`, and `Expresso.Test.PresenterFixtures`
// tells how to write the file again.

import { readFileSync } from "node:fs";
import { parse as parseDeck } from "../src/deck.ts";
import type { Deck } from "../src/deck.ts";
import { parse as parseProgram } from "../src/program.ts";
import type { Program } from "../src/program.ts";
import type { State } from "../src/state.ts";

type Raw = {
  fields: string[];
  help: [string, [string, string][]][];
  decks: Record<string, { deck: unknown; program: unknown }>;
  cases: {
    deck: string;
    start: unknown[];
    events: unknown[][];
    results: [unknown[], boolean, string[], [string, string] | null][];
  }[];
};

export const raw: Raw = JSON.parse(
  readFileSync(new URL("./fixtures/presenter.json", import.meta.url), "utf8"),
);

// The key of a deck in the fixture file, such as `1,3,2` or
// `1,2 fade,zoom`.
export function key(counts: readonly number[], kinds: readonly string[] = []) {
  const steps = counts.join(",");
  return kinds.length === 0 ? steps : `${steps} ${kinds.join(",")}`;
}

// The JSON texts of the list of the steps and of the program of a deck, as the
// renderer writes them.
export function texts(name: string): { deck: string; program: string } {
  const found = raw.decks[name];
  if (found === undefined) {
    throw new Error(
      `The fixture file has no deck "${name}". Add it to Expresso.Test.PresenterFixtures.`,
    );
  }
  return {
    deck: JSON.stringify(found.deck),
    program: JSON.stringify(found.program),
  };
}

// The list of the steps and the program of a deck.
export function load(name: string): { deck: Deck; program: Program } {
  const found = texts(name);
  return { deck: parseDeck(found.deck), program: parseProgram(found.program) };
}

// A state from an array of the fixture file.
export function stateOf(values: readonly unknown[]): State {
  return Object.fromEntries(
    raw.fields.map((field, index) => [field, values[index]]),
  ) as State;
}
