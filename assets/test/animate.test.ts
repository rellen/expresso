import { test } from "node:test";
import assert from "node:assert/strict";
import { animate } from "../src/dom.ts";
import type { Transition } from "../src/interpreter.ts";
import type { Pair } from "../src/morph.ts";

// `animate` reads the global `window` and `document`. The fake browser
// models the parts of the View Transitions API that the morph uses:
//
// 1. A new transition stops the transition before it, and the `finished`
//    promise of the stopped transition then fulfills.
// 2. The browser captures the old state in a later task, after the
//    microtasks. The capture records the name of each element.
// 3. The browser then runs the update, and `finished` fulfills at the end.

type FakeElement = { id: string; style: { viewTransitionName: string } };

type Capture = { old: Record<string, string>; new: Record<string, string> };

function element(id: string): FakeElement {
  return { id, style: { viewTransitionName: "" } };
}

// A pair of the morph between two fake elements.
function pair(from: FakeElement, to: FakeElement): Pair {
  return {
    name: "expresso-morph-1",
    from: from as unknown as Element,
    to: to as unknown as Element,
  };
}

function fakeBrowser(elements: FakeElement[]): {
  captures: Capture[];
  end: () => void;
} {
  const names = () =>
    Object.fromEntries(
      elements.map((each) => [each.id, each.style.viewTransitionName]),
    );
  const captures: Capture[] = [];
  let active: (() => void) | null = null;

  (globalThis as unknown as { window: unknown }).window = {
    matchMedia: () => ({ matches: false }),
  };
  (globalThis as unknown as { document: unknown }).document = {
    documentElement: { dataset: {} },
    startViewTransition: (update: () => void) => {
      active?.();
      let finish = () => {};
      const finished = new Promise<void>((resolve) => (finish = resolve));
      active = finish;
      setTimeout(() => {
        const old = names();
        update();
        captures.push({ old, new: names() });
      });
      return { finished };
    },
  };
  return {
    captures,
    end: () => {
      active?.();
      active = null;
    },
  };
}

const next: Transition = { kind: "slide", direction: "forward" };

// Wait for the tasks and the microtasks of the fake browser.
const settle = () => new Promise((resolve) => setTimeout(resolve, 5));

test("a transition gives the names of its pairs, and removes them at its end", async () => {
  const [a, b] = [element("a"), element("b")];
  const browser = fakeBrowser([a, b]);
  animate(next, () => {}, [pair(a, b)]);
  await settle();

  assert.deepEqual(browser.captures, [
    {
      old: { a: "expresso-morph-1", b: "" },
      new: { a: "", b: "expresso-morph-1" },
    },
  ]);

  browser.end();
  await settle();
  assert.deepEqual(
    [a.style.viewTransitionName, b.style.viewTransitionName],
    ["", ""],
  );
});

// The case of issue 246: the second transition names the partner of the
// first one, and it stops the first one. The end of the first transition
// must not remove that name before the second transition captures it.
test("a transition that a later one stops keeps the names of the later one", async () => {
  const [a, b, c] = [element("a"), element("b"), element("c")];
  const browser = fakeBrowser([a, b, c]);
  animate(next, () => {}, [pair(a, b)]);
  await settle();
  animate(next, () => {}, [pair(b, c)]);
  await settle();

  assert.deepEqual(browser.captures[1], {
    old: { a: "", b: "expresso-morph-1", c: "" },
    new: { a: "", b: "", c: "expresso-morph-1" },
  });

  browser.end();
  await settle();
  assert.deepEqual(
    [a, b, c].map((each) => each.style.viewTransitionName),
    ["", "", ""],
  );
});
