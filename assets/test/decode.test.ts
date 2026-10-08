import { test } from "node:test";
import assert from "node:assert/strict";
import {
  DecodeError,
  boolean,
  integer,
  is,
  list,
  literal,
  nullable,
  number,
  object,
  oneOf,
  openObject,
  partial,
  string,
  tuple,
  union,
} from "../src/decode.ts";
import type { Decoder } from "../src/decode.ts";
import { decodeCommand, decodeMessage, decodeState } from "../src/schema.ts";
import { position } from "./messages.ts";

// The message of the error that a decoder throws for a value.
function error<T>(decoder: Decoder<T>, value: unknown): string {
  try {
    decoder(value);
  } catch (caught) {
    assert.ok(caught instanceof DecodeError);
    return caught.message;
  }
  assert.fail(`the decoder took ${JSON.stringify(value)}`);
}

test("a decoder returns a value that agrees with it", () => {
  assert.equal(boolean(true), true);
  assert.equal(string(/^a/)("ab"), "ab");
  assert.equal(integer(1)(3), 3);
  assert.equal(number(0, 1)(0.5), 0.5);
  assert.equal(literal("set")("set"), "set");
  assert.equal(oneOf(["a", "b"])("b"), "b");
  assert.equal(nullable(integer())(null), null);
  assert.deepEqual(list(integer())([1, 2]), [1, 2]);
  assert.deepEqual(tuple(literal("step"), integer())(["step", -1]), [
    "step",
    -1,
  ]);
  assert.deepEqual(partial({ a: integer() })({}), {});
});

test("an error names the path of the wrong part", () => {
  const decoder = object({ modes: list(object({ keys: list(string()) })) });

  assert.equal(
    error(decoder, { modes: [{ keys: [] }, { keys: ["j", 2] }] }),
    "$.modes[1].keys[1]: expected a string",
  );
  assert.equal(
    error(decoder, { modes: [], x: 1 }),
    "$.x: expected no such key",
  );
  assert.equal(error(decoder, {}), "$.modes: expected a value");
  assert.equal(error(decoder, []), "$: expected an object");
});

test("a number decoder refuses a value that is not finite, and an integer decoder a fraction", () => {
  for (const value of [Number.NaN, Infinity, "1", null]) {
    assert.equal(is(number(), value), false, String(value));
  }
  assert.equal(is(integer(), 1.5), false);
  assert.equal(is(integer(0), -1), false);
  assert.equal(is(number(0, 1), 1.01), false);
});

test("an object refuses a key of Object.prototype, and does not read it from the prototype", () => {
  const decoder = object({ a: integer() });

  assert.equal(
    error(decoder, JSON.parse('{"a":1,"constructor":1}')),
    "$.constructor: expected no such key",
  );
  assert.equal(
    error(partial({ a: integer() }), JSON.parse('{"toString":0}')),
    "$.toString: expected no such key",
  );
  assert.equal(
    error(object({ toString: integer() }), {}),
    "$.toString: expected a value",
  );
});

test("an open object takes other keys and does not return them", () => {
  const decoder = openObject({ a: integer() });

  assert.deepEqual(decoder({ a: 1, b: 2 }), { a: 1 });
  assert.equal(error(decoder, { b: 2 }), "$.a: expected a value");
});

test("a union tries each decoder in order, and names the union in its error", () => {
  const decoder = union("a number or a string", integer(), string());

  assert.equal(decoder(1), 1);
  assert.equal(decoder("x"), "x");
  assert.equal(error(decoder, true), "$: expected a number or a string");
});

test("a decoder does not catch an error that is not a DecodeError", () => {
  const broken: Decoder<never> = () => {
    throw new TypeError("broken");
  };

  assert.throws(() => union("x", broken)(1), TypeError);
  assert.throws(() => is(broken, 1), TypeError);
});

test("the command decoder takes for each field only a value of its type", () => {
  assert.ok(is(decodeCommand, ["set", "view", "speaker"]));
  assert.ok(is(decodeCommand, ["toggle", "blank"]));
  assert.equal(is(decodeCommand, ["set", "view", true]), false);
  assert.equal(is(decodeCommand, ["set", "digits", "1a"]), false);
  assert.equal(is(decodeCommand, ["toggle", "digits"]), false);
  assert.equal(is(decodeCommand, ["goto_slide", 0]), false);
});

test("the state decoder takes exactly the fields of the state", () => {
  const state = {
    index: 0,
    view: "present",
    blank: false,
    digits: "",
    help: false,
    progress: true,
    every: false,
    overview: false,
    selected: 1,
    undim: false,
    menu: false,
    cursor: 0,
  };

  assert.deepEqual(decodeState(state), state);
  assert.equal(is(decodeState, { ...state, selected: 0 }), false);
  assert.equal(is(decodeState, { ...state, extra: 1 }), false);
});

test("the message decoder takes a message with other keys", () => {
  const message = position({ slide: 2, time: 5 });

  assert.ok(is(decodeMessage, { ...message, from: "an extension" }));
  assert.equal(is(decodeMessage, { ...message, expresso: "other" }), false);
  assert.equal(is(decodeMessage, { ...message, time: Infinity }), false);
});
