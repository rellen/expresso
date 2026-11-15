import { test } from "node:test";
import assert from "node:assert/strict";

// The list of the embeds comes after the script in the document, so a call of
// `load` can come before the browser received the list. `load` reads the
// global `document` and `navigator`, and it keeps the list of its first read,
// so this test has its own file. Node runs each test file in its own process.
test("load looks for the list again while the browser reads the document", async () => {
  const attributes: Record<string, string> = {};
  const frame = {
    dataset: { embed: "0" } as Record<string, string | undefined>,
    setAttribute: (name: string, value: string) => {
      attributes[name] = value;
    },
    addEventListener: () => undefined,
    parentElement: null,
  };
  const elements: Record<string, unknown> = {
    "slide-1": { querySelectorAll: () => [frame] },
  };
  const page = {
    readyState: "loading",
    getElementById: (id: string) => elements[id] ?? null,
  };
  Object.assign(globalThis, { document: page });
  Object.defineProperty(globalThis, "navigator", {
    value: { onLine: true },
    configurable: true,
  });
  const { load } = await import("../src/embed.ts");

  load(1);
  assert.deepEqual(attributes, {});

  elements["expresso-embeds"] = {
    textContent: JSON.stringify([{ kind: "srcdoc", value: "<p>a</p>" }]),
  };
  page.readyState = "complete";
  load(1);
  assert.deepEqual(attributes, { srcdoc: "<p>a</p>" });
});
