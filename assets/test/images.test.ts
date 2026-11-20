import { test } from "node:test";
import assert from "node:assert/strict";

import {
  FALLBACK,
  LIMIT,
  SELECTOR,
  idle,
  load,
  ready,
  request,
} from "../src/images.ts";
import type { Image } from "../src/images.ts";

// A fake `img` element. `finish` makes the image complete and sends the event
// `load` or `error`.
function image(
  loading: string,
  complete = false,
): Image & { finish(type: "load" | "error"): void } {
  const listeners: Record<"load" | "error", (() => void)[]> = {
    load: [],
    error: [],
  };
  const fake = {
    loading,
    complete,
    addEventListener(type: "load" | "error", listener: () => void): void {
      listeners[type].push(listener);
    },
    finish(type: "load" | "error"): void {
      fake.complete = true;
      for (const listener of listeners[type]) {
        listener();
      }
    },
  };
  return fake;
}

// True when a promise resolved after the queue of the microtasks is empty.
async function settled(promise: Promise<unknown>): Promise<boolean> {
  let done = false;
  void promise.then(() => {
    done = true;
  });
  await new Promise((resolve) => setImmediate(resolve));
  return done;
}

test("ready resolves at once for a complete image", async () => {
  assert.equal(await settled(ready(image("eager", true))), true);
});

test("ready waits for the load of an image", async () => {
  const waiting = image("eager");
  const promise = ready(waiting);
  assert.equal(await settled(promise), false);
  waiting.finish("load");
  assert.equal(await settled(promise), true);
});

test("ready resolves for an image with no file", async () => {
  const missing = image("eager");
  const promise = ready(missing);
  missing.finish("error");
  assert.equal(await settled(promise), true);
});

test("request makes each lazy image eager, and waits for each image", async () => {
  const lazy = image("lazy");
  const eager = image("eager", true);
  const promise = request([lazy, eager]);
  assert.equal(lazy.loading, "eager");
  assert.equal(eager.loading, "eager");
  assert.equal(await settled(promise), false);
  lazy.finish("load");
  assert.equal(await settled(promise), true);
});

test("idle asks the browser for an idle period, with a limit of time", () => {
  const calls: string[] = [];
  let options: { timeout: number } | undefined;
  idle(() => calls.push("idle"), {
    requestIdleCallback: (callback, given) => {
      options = given;
      callback();
    },
    setTimeout: () => assert.fail("a browser with idle periods needs no timer"),
  });
  assert.deepEqual(calls, ["idle"]);
  assert.deepEqual(options, { timeout: LIMIT });
});

test("idle waits for a time in a browser with no requestIdleCallback", () => {
  const calls: string[] = [];
  let delay: number | undefined;
  idle(() => calls.push("idle"), {
    setTimeout: (callback, given) => {
      delay = given;
      callback();
    },
  });
  assert.deepEqual(calls, ["idle"]);
  assert.equal(delay, FALLBACK);
});

test("load asks for each image of the selector one time", async () => {
  const lazy = image("lazy");
  const selectors: string[] = [];
  Object.assign(globalThis, {
    document: {
      querySelectorAll: (selector: string) => {
        selectors.push(selector);
        return [lazy];
      },
    },
  });
  const first = load();
  assert.equal(lazy.loading, "eager");
  lazy.finish("load");
  await first;
  assert.equal(load(), first);
  assert.deepEqual(selectors, [SELECTOR]);
});
