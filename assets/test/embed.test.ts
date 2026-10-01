import { test } from "node:test";
import assert from "node:assert/strict";
import { attribute } from "../src/embed.ts";
import { decodeWrittenEmbeds } from "../src/schema.ts";

test("attribute gives src for an address and srcdoc for the text of a file", () => {
  assert.deepEqual(attribute({ kind: "src", value: "https://example.com/" }), [
    "src",
    "https://example.com/",
  ]);
  assert.deepEqual(attribute({ kind: "srcdoc", value: "<p>a</p>" }), [
    "srcdoc",
    "<p>a</p>",
  ]);
});

test("the decoder takes the list that the renderer writes, and refuses a different kind", () => {
  const list = [
    { kind: "srcdoc", value: "<p>a</p>" },
    { kind: "src", value: "https://example.com/" },
  ];
  assert.deepEqual(decodeWrittenEmbeds(list), list);
  assert.throws(() => decodeWrittenEmbeds([{ kind: "href", value: "x" }]));
});

// A fake document with one slide and two frames: a local page and an address.
// `load` reads the global `document` and `navigator`, so the test puts fakes
// there. Node runs each test file in its own process.
type FakeFrame = {
  dataset: Record<string, string | undefined>;
  attributes: Record<string, string>;
  setAttribute: (name: string, value: string) => void;
  addEventListener: () => void;
  parentElement: null;
};

function frame(embed: number): FakeFrame {
  const attributes: Record<string, string> = {};
  return {
    dataset: { embed: String(embed) },
    attributes,
    setAttribute: (name, value) => {
      attributes[name] = value;
    },
    addEventListener: () => undefined,
    parentElement: null,
  };
}

test("load gives each frame its source one time, and no address while the browser is offline", async () => {
  const frames = [frame(0), frame(1)];
  const list = [
    { kind: "srcdoc", value: "<p>a</p>" },
    { kind: "src", value: "https://example.com/" },
  ];
  const section = { querySelectorAll: () => frames };
  const elements: Record<string, unknown> = {
    "expresso-embeds": { textContent: JSON.stringify(list) },
    "slide-1": section,
  };
  const online = { onLine: false };
  Object.assign(globalThis, {
    document: { getElementById: (id: string) => elements[id] ?? null },
  });
  Object.defineProperty(globalThis, "navigator", {
    value: online,
    configurable: true,
  });
  const { load } = await import("../src/embed.ts");

  load(1);
  assert.deepEqual(frames[0]?.attributes, { srcdoc: "<p>a</p>" });
  assert.deepEqual(frames[1]?.attributes, {});

  online.onLine = true;
  frames[0]?.setAttribute("srcdoc", "changed");
  load(1);
  assert.deepEqual(frames[0]?.attributes, { srcdoc: "changed" });
  assert.deepEqual(frames[1]?.attributes, { src: "https://example.com/" });
});
