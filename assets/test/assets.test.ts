import { test } from "node:test";
import assert from "node:assert/strict";
import { restore } from "../src/assets.ts";
import type { Root } from "../src/assets.ts";

// A fake element with attributes, and a fake root that finds elements by the
// presence or the value of an attribute, as the selectors of `restore` ask.
type Fake = {
  attributes: Record<string, string>;
  getAttribute: (name: string) => string | null;
  setAttribute: (name: string, value: string) => void;
};

function element(attributes: Record<string, string>): Fake {
  return {
    attributes,
    getAttribute: (name) => attributes[name] ?? null,
    setAttribute: (name, value) => {
      attributes[name] = value;
    },
  };
}

function root(elements: Fake[]): Root {
  const has = (selector: string) => {
    const name = /^\[([^\]=]+)\]$/.exec(selector)?.[1];
    return (each: Fake) => name !== undefined && name in each.attributes;
  };
  return {
    querySelector: ((selector: string) =>
      elements.find(has(selector)) ?? null) as Root["querySelector"],
    querySelectorAll: ((selector: string) =>
      elements.filter(has(selector))) as unknown as Root["querySelectorAll"],
  };
}

test("restore copies the value of the first element into each reference", () => {
  const first = element({
    "data-asset-0": "src",
    src: "data:image/png;base64,AAAA",
  });
  const video = element({
    "data-asset-1": "poster",
    poster: "data:image/png;base64,BBBB",
  });
  const copy = element({ "data-asset-src": "0" });
  const poster = element({ "data-asset-poster": "1" });

  restore(root([first, video, copy, poster]));

  assert.equal(copy.attributes["src"], "data:image/png;base64,AAAA");
  assert.equal(poster.attributes["poster"], "data:image/png;base64,BBBB");
});

test("a reference with no first element stays as it is", () => {
  const copy = element({ "data-asset-src": "7" });
  restore(root([copy]));
  assert.equal(copy.attributes["src"], undefined);
});
