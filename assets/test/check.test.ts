import { test } from "node:test";
import assert from "node:assert/strict";
import {
  accessibility,
  describe,
  detach,
  engine,
  first,
  write,
} from "../src/check.ts";
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
    querySelectorAll: () => [],
    createElement: () => ({ type: "", id: "", textContent: "" }),
    body,
  };
  return { properties, appended, body };
}

const finding = (
  where: string,
  rule: string,
  ...elements: string[]
): Finding => ({
  where,
  rule,
  help: "Help",
  elements,
});

test("first keeps the first finding of each rule on each element", () => {
  const findings = [
    finding("Slide 1, step 1", "color-contrast", "the text area “a”"),
    finding("Slide 1, step 2", "color-contrast", "the text area “a”"),
    finding("Slide 1, step 2", "color-contrast", "the list “b”"),
    finding("The menu", "region", "the text area “a”"),
  ];
  assert.deepEqual(first(findings), [findings[0], findings[2], findings[3]]);
});

test("first keeps only the elements of a view that no step gave", () => {
  const findings = [
    finding("Slide 1, step 1", "color-contrast", "the text area “a”"),
    finding(
      "The overview",
      "color-contrast",
      "the text area “a”",
      "#menu > li",
    ),
    finding("The handout view", "color-contrast", "the text area “a”"),
  ];
  assert.deepEqual(first(findings), [
    findings[0],
    finding("The overview", "color-contrast", "#menu > li"),
  ]);
});

test("describe names the element of a slide, and keeps another selector", () => {
  const area = {
    classList: { contains: () => false, 0: "text-area" },
    tagName: "DIV",
    textContent: "  Grey   on grey  ",
    querySelector: () => null,
    closest: () => area,
  };
  const item = { closest: () => null };
  (globalThis as { document?: unknown }).document = {
    querySelector: (selector: string) => {
      if (selector === "[") throw new Error("bad selector");
      return selector === ".text-area" ? area : selector === "li" ? item : null;
    },
  };
  assert.equal(describe(".text-area"), "the text area “Grey on grey”");
  assert.equal(describe("li"), "li");
  assert.equal(describe(".none"), ".none");
  assert.equal(describe("["), "[");
});

test("detach takes the parts outside the slides out, and puts them back in their places", () => {
  const children: string[] = ["slides", "menu", "help", "handout", "script"];
  const part = (name: string) => ({
    name,
    parentNode: {
      insertBefore: (
        element: { name: string },
        next: { name: string } | null,
      ) => {
        const at =
          next === null ? children.length : children.indexOf(next.name);
        children.splice(at, 0, element.name);
      },
    },
    get nextSibling() {
      const next = children[children.indexOf(name) + 1];
      return next === undefined ? null : { name: next };
    },
    remove: () => children.splice(children.indexOf(name), 1),
  });
  let selector = "";
  (globalThis as { document?: unknown }).document = {
    querySelectorAll: (given: string) => {
      selector = given;
      return ["menu", "help", "handout"].map(part);
    },
  };

  const restore = detach();
  assert.equal(selector, "#menu, #help, .handout");
  assert.deepEqual(children, ["slides", "script"]);
  restore();
  assert.deepEqual(children, ["slides", "menu", "help", "handout", "script"]);
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
    (selector) => `the element ${selector}`,
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
      elements: ["the element .dim"],
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
