import { test } from "node:test";
import assert from "node:assert/strict";
import { search } from "../src/search.ts";

// A fake list of keys: two sections, the first one current, with rows.
function list() {
  const attributes = new Set<string>();
  const row = (words: string) => ({ dataset: { words }, hidden: false });
  const section = (current: boolean, words: string[]) => {
    const rows = words.map(row);
    return {
      rows,
      open: current,
      hasAttribute: (name: string) => current && name === "data-current",
      querySelector: () => rows.find((each) => !each.hidden) ?? null,
    };
  };
  const present = section(true, ["j next step", "d code in full color"]);
  const overview = section(false, [
    "j select the next slide",
    "o close the overview",
  ]);
  const field = { value: "" };
  const dialog = {
    attributes,
    field,
    present,
    overview,
    toggleAttribute: (name: string, on: boolean) => {
      if (on) attributes.add(name);
      else attributes.delete(name);
    },
    querySelector: () => field,
    querySelectorAll: (selector: string) =>
      selector === "li[data-words]"
        ? [...present.rows, ...overview.rows]
        : [present, overview],
  };
  return dialog;
}

test("search hides each row whose words do not hold the text, and opens each section with a match", () => {
  const dialog = list();
  search(dialog as unknown as HTMLElement, "Next");

  assert.deepEqual(
    dialog.present.rows.map((row) => row.hidden),
    [false, true],
  );
  assert.deepEqual(
    dialog.overview.rows.map((row) => row.hidden),
    [false, true],
  );
  assert.equal(dialog.overview.open, true);
  assert.ok(dialog.attributes.has("data-searching"));
  assert.equal(dialog.field.value, "Next");
});

test("search with an empty text shows each row again", () => {
  const dialog = list();
  search(dialog as unknown as HTMLElement, "full color");
  assert.equal(dialog.overview.open, false);

  search(dialog as unknown as HTMLElement, "");
  const rows = [...dialog.present.rows, ...dialog.overview.rows];
  assert.ok(rows.every((row) => !row.hidden));
  assert.equal(dialog.attributes.has("data-searching"), false);
});
