import { test } from "node:test";
import assert from "node:assert/strict";
import {
  follow,
  fromHash,
  helpMode,
  prevented,
  run,
  toHash,
  transition,
  upcoming,
} from "../src/interpreter.ts";
import type { Event, Result } from "../src/interpreter.ts";
import type { Deck } from "../src/deck.ts";
import type { Command, Program, Region } from "../src/program.ts";
import type { State } from "../src/state.ts";
import { load, raw, stateOf } from "./fixtures.ts";
import { nth } from "./nth.ts";

// One event of the fixture file, through the functions that `main.ts` calls
// for it.
function apply(
  program: Program,
  deck: Deck,
  state: State,
  event: unknown[],
): Result {
  const [kind, first, second, third] = event;
  switch (kind) {
    case "key":
      return run(program, deck, state, { kind: "key", key: first as string });
    case "click": {
      const input: Event = {
        kind: "click",
        region: first as Region,
        element: second as Command[] | null,
      };
      return run(program, deck, state, input);
    }
    case "swipe":
      return run(program, deck, state, {
        kind: "swipe",
        direction: first as "left" | "right",
      });
    case "hash":
      return { state: fromHash(state, first as string, deck), effects: [] };
    case "message": {
      const data = {
        expresso: "position",
        slide: first,
        step: second,
        blank: third,
        time: 1,
      };
      return { state: follow(state, data, deck), effects: [] };
    }
  }
  throw new Error(`An unknown event: ${String(kind)}`);
}

test("the TypeScript interpreter returns the result of the Elixir interpreter for each event of the fixtures", () => {
  let events = 0;
  for (const [number, each] of raw.cases.entries()) {
    const { deck, program } = load(each.deck);
    let state = stateOf(each.start);
    for (const [index, event] of each.events.entries()) {
      const result = apply(program, deck, state, event);
      const change = transition(state, result.state, deck);
      const [expected, stopped, effects, kind] = nth(each.results, index);
      const where = `case ${number}, event ${index}: ${JSON.stringify(event)}`;

      assert.deepEqual(result.state, stateOf(expected), where);
      assert.equal(prevented(state, result), stopped, where);
      assert.deepEqual(result.effects, effects, where);
      assert.deepEqual(
        change === null ? null : [change.kind, change.direction],
        kind,
        where,
      );
      state = result.state;
      events++;
    }
  }
  assert.ok(events >= 900, `only ${events} events`);
});

test("run throws for a command that the script does not know", () => {
  const { deck, program } = load("1,2");
  const mode = program.modes.find((each) => each.name === "present");
  assert.ok(mode);
  const broken = {
    ...program,
    modes: [{ ...mode, other: [["jump", 1]] as unknown as Command[] }],
  };

  assert.throws(
    () => run(broken, deck, program.state, { kind: "key", key: "x" }),
    { message: 'An unknown command: ["jump",1]' },
  );
});

test("a state with no change is the same object", () => {
  const { deck, program } = load("1,2");
  const state = program.state;
  const result = run(program, deck, state, { kind: "key", key: "x" });

  assert.equal(result.state, state);
  assert.equal(prevented(state, result), false);
});

test("toHash returns the slide and the step, and #1.1 for a deck with no slide", () => {
  const { deck, program } = load("1,2");
  assert.equal(toHash({ ...program.state, index: 2 }, deck), "#2.2");

  const empty = load("");
  assert.equal(toHash(empty.program.state, empty.deck), "#1.1");
});

test("upcoming returns the next step, and null at the last step", () => {
  const { deck, program } = load("1,2");
  const first = program.state;

  assert.equal(upcoming(first, deck)?.index, 1);
  assert.equal(upcoming({ ...first, index: 2 }, deck), null);
});

test("helpMode returns the mode under the list of keys", () => {
  const { program } = load("1,2");
  const help = { ...program.state, help: true };

  assert.equal(helpMode(program, help), "present");
  assert.equal(helpMode(program, { ...help, view: "speaker" }), "speaker");
  assert.equal(helpMode(program, { ...help, overview: true }), "overview");
});
