// A fake page for the tests of `main.ts`. Node has no DOM, so this module puts
// a fake `document`, `window`, `location` and `history` on the global object.
//
// `main.ts` runs when the module loads, and it reads the page one time.
// Therefore a test file calls `fakePage` in front of the import of `main.ts`.
// Node runs each test file in its own process, so each file gets one page.

import assert from "node:assert/strict";

type FakeElement = {
  id: string;
  dataset: Record<string, string | undefined>;
  style: { display: string };
};

type Key = {
  key: string;
  ctrlKey?: boolean;
  altKey?: boolean;
  metaKey?: boolean;
};

export type FakePage = {
  slides: FakeElement[];
  body: { dataset: Record<string, string | undefined> };
  location: { hash: string };
  // The fragments that `history.replaceState` got, in sequence.
  written: string[];
  // Give one key to `main.ts`. The result tells if `main.ts` stopped the
  // default operation of the browser.
  press: (key: string | Key) => boolean;
  // Type a fragment into the address bar.
  navigate: (hash: string) => void;
};

export function fakePage(maxSteps: number[], hash = ""): FakePage {
  const slides: FakeElement[] = maxSteps.map((max, index) => ({
    id: `slide-${index + 1}`,
    dataset: { maxStep: String(max) },
    style: { display: "none" },
  }));
  const listeners: Record<string, (event: unknown) => void> = {};
  const listen = (name: string, listener: (event: unknown) => void) => {
    listeners[name] = listener;
  };

  const page: FakePage = {
    slides,
    body: { dataset: {} },
    location: { hash },
    written: [],
    press: (key) => {
      const listener = listeners.keydown;
      assert.ok(listener, "main.ts registered no function for keydown");
      let stopped = false;
      const event = typeof key === "string" ? { key } : key;
      listener({ ...event, preventDefault: () => (stopped = true) });
      return stopped;
    },
    navigate: (hash) => {
      const listener = listeners.hashchange;
      assert.ok(listener, "main.ts registered no function for hashchange");
      page.location.hash = hash;
      listener({});
    },
  };

  const global = globalThis as unknown as Record<string, unknown>;
  global.document = {
    body: page.body,
    getElementsByClassName: (name: string) => (name === "slide" ? slides : []),
    getElementById: (id: string) =>
      slides.find((slide) => slide.id === id) ?? null,
    addEventListener: listen,
  };
  global.window = { addEventListener: listen };
  global.location = page.location;
  global.history = {
    replaceState: (_data: unknown, _unused: string, url: string) => {
      page.written.push(url);
      page.location.hash = url;
    },
  };
  return page;
}
