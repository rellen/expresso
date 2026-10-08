import { test } from "node:test";
import assert from "node:assert/strict";
import { play, shows } from "../src/video.ts";
import type { Video } from "../src/video.ts";
import { decodeWrittenVideos } from "../src/schema.ts";

test("the decoder takes the list that the renderer writes, and refuses another source", () => {
  const list = ["data:video/webm;base64,AAAA", "data:video/mp4;base64,BBBB"];
  assert.deepEqual(decodeWrittenVideos(list), list);
  assert.throws(() => decodeWrittenVideos(["https://example.com/clip.webm"]));
});

// A fake element with `data-on`, and its parent.
type FakeElement = {
  getAttribute: (name: string) => string | null;
  parentElement: { closest: (selector: string) => FakeElement | null } | null;
};

function overlay(on: string, parent: FakeElement | null): FakeElement {
  return {
    getAttribute: () => on,
    parentElement: { closest: () => parent },
  };
}

// A fake video inside an element with `data-on`, or inside none.
function video(
  number: number,
  on: FakeElement | null = null,
): Video & {
  calls: string[];
} {
  const calls: string[] = [];
  const fake = {
    calls,
    dataset: { video: String(number) },
    paused: true,
    currentTime: 0,
    src: "",
    parentElement: null,
    closest: () => on as unknown as Element | null,
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

test("shows is true when each parent with an overlay shows at the step", () => {
  assert.equal(shows(video(0), 1), true);
  assert.equal(shows(video(0, overlay("2 3", null)), 2), true);
  assert.equal(shows(video(0, overlay("2 3", null)), 1), false);
  assert.equal(shows(video(0, overlay("2 3", overlay("3", null))), 2), false);
  assert.equal(shows(video(0, overlay("2 3", overlay("3", null))), 3), true);
});

// `play` reads the global `document`, so the test puts a fake there. Node
// runs each test file in its own process.
test("play gives a video its source, pauses it when covered or on another slide, and starts it again on a new visit", () => {
  const first = video(0);
  const second = video(0, overlay("2", null));
  const slides: Record<string, unknown> = {
    "expresso-videos": { textContent: '["data:video/webm;base64,AAAA"]' },
    "slide-1": { querySelectorAll: () => [first] },
    "slide-2": { querySelectorAll: () => [second] },
  };
  (globalThis as { document?: unknown }).document = {
    getElementById: (id: string) => slides[id] ?? null,
  };

  play(1, 1, false);
  assert.equal(first.src, "data:video/webm;base64,AAAA");
  assert.equal(first.paused, false);

  first.currentTime = 4;
  play(1, 1, true);
  assert.equal(first.paused, true);
  play(1, 1, false);
  assert.equal(first.paused, false);
  assert.equal(first.currentTime, 4);

  play(2, 1, false);
  assert.equal(first.paused, true);
  assert.equal(second.src, "");

  play(2, 2, false);
  assert.equal(second.paused, false);

  play(1, 1, false);
  assert.equal(second.paused, true);
  assert.equal(first.paused, false);
  assert.equal(first.currentTime, 0);

  play(null, 1, false);
  assert.equal(first.paused, true);
});
