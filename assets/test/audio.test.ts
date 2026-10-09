import { test } from "node:test";
import assert from "node:assert/strict";
import { play } from "../src/audio.ts";
import type { Media } from "../src/media.ts";
import { decodeWrittenAudios } from "../src/schema.ts";

test("the decoder takes the list of sounds that the renderer writes, and refuses another source", () => {
  const list = ["data:audio/mpeg;base64,AAAA", "data:audio/ogg;base64,BBBB"];
  assert.deepEqual(decodeWrittenAudios(list), list);
  assert.throws(() => decodeWrittenAudios(["data:video/webm;base64,AAAA"]));
});

// A fake sound with no overlay. Its first `play` fails, as a browser refuses
// sound before the first key of the presenter.
function sound(): Media & { calls: string[] } {
  const calls: string[] = [];
  let refused = false;
  const fake = {
    calls,
    dataset: { audio: "0" },
    paused: true,
    currentTime: 0,
    src: "",
    parentElement: null,
    closest: () => null,
    play: () => {
      calls.push("play");
      if (!refused) {
        refused = true;
        return Promise.reject(new Error("NotAllowedError"));
      }
      fake.paused = false;
      return Promise.resolve();
    },
    pause: () => {
      calls.push("pause");
      fake.paused = true;
    },
  };
  return fake;
}

// `play` reads the global `document`, so the test puts a fake there. Node
// runs each test file in its own process.
test("a sound gets its source, tries again after a refusal, and pauses on another slide", async () => {
  const first = sound();
  const elements: Record<string, unknown> = {
    "expresso-audios": { textContent: '["data:audio/ogg;base64,AAAA"]' },
    "slide-1": {
      querySelectorAll: (selector: string) =>
        selector === "[data-audio]" ? [first] : [],
    },
    "slide-2": { querySelectorAll: () => [] },
  };
  (globalThis as { document?: unknown }).document = {
    getElementById: (id: string) => elements[id] ?? null,
  };

  play(1, 1, false);
  assert.equal(first.src, "data:audio/ogg;base64,AAAA");
  await Promise.resolve();
  assert.equal(first.paused, true);

  // The next change of the state, such as the first key, tries again.
  play(1, 2, false);
  assert.equal(first.paused, false);
  assert.deepEqual(first.calls, ["play", "play"]);

  play(2, 1, false);
  assert.equal(first.paused, true);
});
