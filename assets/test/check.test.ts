import { test } from "node:test";
import assert from "node:assert/strict";
import { accessibility, engine, first, write } from "../src/check.ts";
import type { Axe, Finding } from "../src/check.ts";

// A stub of the parts of the document that the check reads: the style of the
// root, the slides by id, and the `body` for the result.
function stubDocument(): {
  properties: Map<string, string>;
  appended: { type: string; id: string; textContent: string }[];
  body: { dataset: Record<string, string> };
} {
  const properties = new Map<string, string>();
  const appended: { type: string; id: string; textContent: string }[] = [];
  const body = {
    dataset: {} as Record<string, string>,
    append: (element: { type: string; id: string; textContent: string }) =>
      appended.push(element),
  };
  (globalThis as { document?: unknown }).document = {
    documentElement: {
      style: {
        setProperty: (name: string, value: string) =>
          properties.set(name, value),
        removeProperty: (name: string) => properties.delete(name),
      },
    },
    getElementById: (id: string) => ({ id }),
    createElement: () => ({ type: "", id: "", textContent: "" }),
    body,
  };
  return { properties, appended, body };
}

const finding = (where: string, rule: string, target: string): Finding => ({
  where,
  rule,
  help: "Help",
  targets: [target],
});

test("first keeps the first finding of each rule on each element", () => {
  const findings = [
    finding("Slide 1, step 1", "color-contrast", ".line"),
    finding("Slide 1, step 2", "color-contrast", ".line"),
    finding("Slide 1, step 2", "color-contrast", ".other"),
    finding("The menu", "region", ".line"),
  ];
  assert.deepEqual(first(findings), [findings[0], findings[2], findings[3]]);
});

test("engine returns undefined for a page without axe-core", () => {
  (globalThis as { window?: unknown }).window = {};
  assert.equal(engine(), undefined);
  const axe = { run: () => Promise.resolve({ violations: [] }) };
  (globalThis as { window?: unknown }).window = { axe };
  assert.equal(engine(), axe);
});

test("accessibility reads the slide of each step, then the document in each view", async () => {
  const { properties } = stubDocument();
  const contexts: unknown[] = [];
  const shown: string[] = [];
  const axe: Axe = {
    run: (context) => {
      contexts.push(context);
      assert.equal(properties.get("--dur"), "0s");
      const id = (context as { id?: string }).id;
      return Promise.resolve({
        violations:
          id === "slide-2"
            ? [
                {
                  id: "color-contrast",
                  help: "Contrast",
                  nodes: [{ target: [".dim"] }],
                },
              ]
            : [],
      });
    },
  };

  const findings = await accessibility(
    [
      { slide: 1, step: 1 },
      { slide: 2, step: 1 },
      { slide: 2, step: 2 },
    ],
    (index) => shown.push(`step ${index}`),
    [["The menu", () => shown.push("menu")]],
    axe,
  );

  assert.deepEqual(shown, ["step 0", "step 1", "step 2", "menu"]);
  assert.deepEqual(contexts.slice(0, 3), [
    { id: "slide-1" },
    { id: "slide-2" },
    { id: "slide-2" },
  ]);
  assert.equal(contexts[3], (globalThis as { document?: unknown }).document);
  assert.deepEqual(findings, [
    {
      where: "Slide 2, step 1",
      rule: "color-contrast",
      help: "Contrast",
      targets: [".dim"],
    },
  ]);
  assert.equal(properties.has("--dur"), false);
});

test("write puts the result into an element, and escapes each <", () => {
  const { appended, body } = stubDocument();
  write({
    width: 1920,
    height: 1080,
    layout: ["Slide 1, step 1: the text “</script>” goes 3 px past"],
    accessibility: null,
  });
  assert.equal(appended[0]?.id, "check-result");
  assert.equal(appended[0]?.type, "application/json");
  assert.ok(!appended[0]?.textContent.includes("<"));
  assert.equal(
    (JSON.parse(appended[0]?.textContent ?? "") as { layout: string[] })
      .layout[0],
    "Slide 1, step 1: the text “</script>” goes 3 px past",
  );
  assert.equal(body.dataset.check, "done");
});
