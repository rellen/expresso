import { test } from "node:test";
import assert from "node:assert/strict";
import { common, kindOf, modeOf } from "../src/morph.ts";

// An element of the fake document: its classes and its attributes.
function element(
  classes: string[],
  attributes: Record<string, string> = {},
): Element {
  return {
    classList: { contains: (name: string) => classes.includes(name) },
    getAttribute: (name: string) => attributes[name] ?? null,
  } as unknown as Element;
}

test("common pairs the longest common subsequence of two lists, in order", () => {
  assert.deepEqual(
    common(
      ["def", "greet", "(", "name", ")", "do"],
      ["def", "greet", "(", "name", ",", "greeting", ")", "do"],
    ),
    [
      [0, 0],
      [1, 1],
      [2, 2],
      [3, 3],
      [4, 6],
      [5, 7],
    ],
  );
  assert.deepEqual(common([], ["a"]), []);
  assert.deepEqual(common(["a", "b"], ["b", "a"]).length, 1);
});

test("kindOf reads the kind of an element from its class, and the heading from its container", () => {
  assert.equal(kindOf(element(["slide-heading-container"])), "heading");
  assert.equal(kindOf(element(["stat", "dense"])), "stat");
  assert.equal(kindOf(element(["code"])), "code");
  assert.equal(kindOf(element(["spacer"])), null);
});

test("the slide with the higher number gives the mode, in the two directions", () => {
  const first = element(["slide"], { "data-morph": "off" });
  const second = element(["slide"], { "data-morph": "named" });
  assert.equal(modeOf(first, second, 1, 2), "named");
  assert.equal(modeOf(second, first, 2, 1), "named");
  assert.equal(modeOf(second, first, 1, 2), "off");
  assert.equal(modeOf(element(["slide"]), element(["slide"]), 1, 2), "auto");
});
