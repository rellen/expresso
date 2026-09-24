import { test } from "node:test";
import assert from "node:assert/strict";
import { names, rows } from "../src/help.ts";

function keys(view: "present" | "handout" | "speaker"): string[] {
  return rows(view).map(([name]) => name);
}

test("names gives a readable name for each key", () => {
  assert.equal(
    names({
      keys: ["j", "ArrowRight", "ArrowDown", "PageDown", " "],
      action: "forward",
      views: ["present"],
      text: "",
    }),
    "j, →, ↓, Page Down, Space",
  );
  assert.equal(
    names({
      keys: ["k", "ArrowUp", "PageUp"],
      action: "back",
      views: [],
      text: "",
    }),
    "k, ↑, Page Up",
  );
});

test("names gives the label of a binding in place of its keys", () => {
  assert.equal(
    names({
      keys: ["0", "1"],
      action: "digit",
      views: [],
      text: "",
      label: "0 to 9",
    }),
    "0 to 9",
  );
});

test("the handout view lists only j, k, p and ?", () => {
  assert.deepEqual(keys("handout"), ["j", "k", "p", "?"]);
});

test("the present view lists s, and not r", () => {
  const present = keys("present");
  assert.ok(present.includes("s"));
  assert.ok(present.includes("p"));
  assert.ok(!present.includes("r"));
  assert.equal(present[0], "j, →, ↓, Page Down, Space");
});

test("the speaker view lists r, and not p or s", () => {
  const speaker = keys("speaker");
  assert.ok(speaker.includes("r"));
  assert.ok(!speaker.includes("p"));
  assert.ok(!speaker.includes("s"));
});

test("each row has a text", () => {
  for (const view of ["present", "handout", "speaker"] as const) {
    for (const [name, text] of rows(view)) {
      assert.ok(text.length > 0, `${view}: ${name}`);
    }
  }
});
