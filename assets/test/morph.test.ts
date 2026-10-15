import { test } from "node:test";
import assert from "node:assert/strict";
import { common, modeOf, pairs } from "../src/morph.ts";

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

// An element with a signature, and a slide of the fake document with its
// elements that the morph can use.
function signed(signature: string): Element {
  return {
    classList: { contains: () => false },
    getAttribute: (name: string) =>
      name === "data-morph-signature" ? signature : null,
    contains: () => false,
  } as unknown as Element;
}

function slide(...elements: Element[]): Element {
  return { querySelectorAll: () => elements } as unknown as Element;
}

test("the auto morph pairs a signature that occurs one time on each slide", () => {
  const [stat, first, second] = [signed("s"), signed("t"), signed("t")];
  const [partner, other] = [signed("s"), signed("t")];

  const found = pairs(
    slide(stat, first, second),
    slide(partner, other),
    "auto",
  );
  assert.deepEqual(
    found.map((pair) => [pair.from, pair.to, pair.name]),
    [[stat, partner, "expresso-morph-1"]],
  );
  assert.deepEqual(pairs(slide(stat), slide(partner), "named"), []);
});

test("the slide with the higher number gives the mode, in the two directions", () => {
  const first = element(["slide"], { "data-morph": "off" });
  const second = element(["slide"], { "data-morph": "named" });
  assert.equal(modeOf(first, second, 1, 2), "named");
  assert.equal(modeOf(second, first, 2, 1), "named");
  assert.equal(modeOf(second, first, 1, 2), "off");
  assert.equal(modeOf(element(["slide"]), element(["slide"]), 1, 2), "auto");
});
