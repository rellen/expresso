import { test } from "node:test";
import assert from "node:assert/strict";
import { play } from "../src/audio.ts";
import { player } from "../src/media.ts";
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

// A fake sound that plays at each call of `play`, and that can end.
function plain(): Media & { calls: string[] } {
  const calls: string[] = [];
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

function stage(medium: Media): void {
  const elements: Record<string, unknown> = {
    "expresso-audios": { textContent: '["data:audio/ogg;base64,AAAA"]' },
    "slide-1": { querySelectorAll: () => [medium] },
    "slide-2": { querySelectorAll: () => [] },
  };
  (globalThis as { document?: unknown }).document = {
    getElementById: (id: string) => elements[id] ?? null,
  };
}

test("a sound that ended does not play again at a later step, and plays again on a new visit", () => {
  const medium = plain();
  stage(medium);
  const run = player("expresso-audios", "audio");

  run(1, 1, false);
  assert.deepEqual(medium.calls, ["play"]);

  // The sound ends: the browser sets `paused`.
  medium.paused = true;
  medium.currentTime = 2;
  run(1, 2, false);
  run(1, 3, false);
  assert.equal(medium.paused, true);
  assert.deepEqual(medium.calls, ["play"]);

  run(2, 1, false);
  run(1, 1, false);
  assert.equal(medium.paused, false);
  assert.equal(medium.currentTime, 0);
  assert.deepEqual(medium.calls, ["play", "play"]);
});

test("a pause from the controls stays at a later step, and a cover does not undo it", () => {
  const medium = plain();
  stage(medium);
  const run = player("expresso-audios", "audio");

  run(1, 1, false);
  medium.pause();
  run(1, 2, false);
  run(1, 2, true);
  run(1, 2, false);
  assert.equal(medium.paused, true);
  assert.deepEqual(medium.calls, ["play", "pause"]);
});

test("a cover pauses a sound that plays, and the end of the cover plays it again", () => {
  const medium = plain();
  stage(medium);
  const run = player("expresso-audios", "audio");

  run(1, 1, false);
  run(1, 1, true);
  assert.equal(medium.paused, true);
  run(1, 2, false);
  assert.equal(medium.paused, false);
  assert.deepEqual(medium.calls, ["play", "pause", "play"]);
});

// A fake sound whose `play` promise waits. A pause before the promise settles
// rejects it with an `AbortError`, as a browser does.
function slow(): Media & { calls: string[] } {
  const calls: string[] = [];
  let abort: (() => void) | null = null;
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
      fake.paused = false;
      return new Promise<void>((_resolve, reject) => {
        abort = () => {
          reject(
            new DOMException(
              "The play() request was interrupted",
              "AbortError",
            ),
          );
        };
      });
    },
    pause: () => {
      calls.push("pause");
      fake.paused = true;
      abort?.();
      abort = null;
    },
  };
  return fake;
}

test("a pause from the controls before the sound starts stays at a later step", async () => {
  const medium = slow();
  stage(medium);
  const run = player("expresso-audios", "audio");

  run(1, 1, false);
  medium.pause();
  // Let the rejection of the `play` promise come first.
  await new Promise((resolve) => setTimeout(resolve, 0));
  run(1, 2, false);
  run(1, 2, true);
  run(1, 2, false);
  assert.equal(medium.paused, true);
  assert.deepEqual(medium.calls, ["play", "pause"]);
});
