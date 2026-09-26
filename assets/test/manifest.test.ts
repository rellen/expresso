import { test } from "node:test";
import assert from "node:assert/strict";
import { isAdvance, output } from "../gifs/manifest.ts";
import type { Example } from "../gifs/manifest.ts";

const example: Example = {
  name: "present-keys",
  html: "/tmp/present-keys.html",
  address: "",
  actions: ["j", { advance: 90_000 }],
  still: false,
};

test("isAdvance tells a move of the clock from a key", () => {
  assert.equal(isAdvance("j"), false);
  assert.equal(isAdvance({ advance: 90_000 }), true);
});

test("output gives a GIF for an example with motion, and a PNG for a still", () => {
  assert.equal(output(example), "present-keys.gif");
  assert.equal(output({ ...example, still: true }), "present-keys.png");
});
