import { test, before } from "node:test";
import assert from "node:assert/strict";

// `main.ts` runs when the module loads. It reads the limits one time, and it
// gives a function to `addEventListener`. Therefore the fake document goes in
// front of the import, and the test then calls the function that the module
// registered. Node runs each test file in its own process, so the one import
// of this file is enough.

type FakeElement = {
  id: string;
  dataset: Record<string, string | undefined>;
  style: { display: string };
};

const slides: FakeElement[] = [1, 2].map((max, index) => ({
  id: `slide-${index + 1}`,
  dataset: { maxStep: String(max) },
  style: { display: "none" },
}));

const body = { dataset: {} as Record<string, string | undefined> };
let keydown: ((event: { key: string }) => void) | null = null;

const doc = {
  body,
  getElementsByClassName: (name: string) => (name === "slide" ? slides : []),
  getElementById: (id: string) =>
    slides.find((slide) => slide.id === id) ?? null,
  addEventListener: (
    name: string,
    listener: (event: { key: string }) => void,
  ) => {
    if (name === "keydown") {
      keydown = listener;
    }
  },
};

(globalThis as unknown as { document: unknown }).document = doc;

before(async () => {
  await import("../src/main.ts");
});

function press(key: string): void {
  assert.ok(keydown, "main.ts registered no function for keydown");
  keydown({ key });
}

test("registers a function for keydown", () => {
  assert.equal(typeof keydown, "function");
});

test("an unknown key writes nothing, because the state does not change", () => {
  press("x");

  assert.equal(body.dataset.view, undefined);
  assert.equal(slides[0].dataset.step, undefined);
});

test("j moves to the next slide after the last step of the first slide", () => {
  press("j");

  assert.deepEqual(
    slides.map((slide) => slide.style.display),
    ["none", "flex"],
  );
  assert.equal(slides[1].dataset.step, "1");
});

test("j moves to the next step inside the slide", () => {
  press("j");

  assert.equal(slides[1].dataset.step, "2");
});

test("j on the last step of the last slide writes nothing new", () => {
  press("j");

  assert.equal(slides[1].dataset.step, "2");
});

test("k moves back through the steps and the slides", () => {
  press("k");
  assert.equal(slides[1].dataset.step, "1");

  press("k");
  assert.equal(slides[0].dataset.step, "1");
  assert.deepEqual(
    slides.map((slide) => slide.style.display),
    ["flex", "none"],
  );
});

test("p changes the view, and p again changes it back", () => {
  press("p");
  assert.equal(body.dataset.view, "handout");

  press("p");
  assert.equal(body.dataset.view, "present");
});
