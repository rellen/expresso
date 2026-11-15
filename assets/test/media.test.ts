import { test } from "node:test";
import assert from "node:assert/strict";
import { player } from "../src/media.ts";
import type { Media } from "../src/media.ts";

// A fake video with no overlay.
function video(): Media {
  const fake = {
    dataset: { video: "0" },
    paused: true,
    currentTime: 0,
    src: "",
    parentElement: null,
    closest: () => null,
    play: () => {
      fake.paused = false;
      return Promise.resolve();
    },
    pause: () => {
      fake.paused = true;
    },
  };
  return fake;
}

// A fake document with one slide. `player` reads the global `document`.
function page(readyState: string, medium: Media): Record<string, unknown> {
  const elements: Record<string, unknown> = {
    "slide-1": { querySelectorAll: () => [medium] },
  };
  (globalThis as { document?: unknown }).document = {
    readyState,
    getElementById: (id: string) => elements[id] ?? null,
  };
  return elements;
}

const list = { textContent: '["data:video/webm;base64,AAAA"]' };

// The list of the files comes after the script in the document, so the first
// call of a player can come before the browser received the list.
test("a player looks for its list again while the browser reads the document", () => {
  const medium = video();
  const elements = page("loading", medium);
  const play = player("expresso-videos", "video");

  play(1, 1, false);
  assert.equal(medium.src, "");
  assert.equal(medium.paused, true);

  elements["expresso-videos"] = list;
  play(1, 1, false);
  assert.equal(medium.src, "data:video/webm;base64,AAAA");
  assert.equal(medium.paused, false);
});

test("a player reads its list one time", () => {
  const medium = video();
  const elements = page("loading", medium);
  elements["expresso-videos"] = list;
  const play = player("expresso-videos", "video");

  play(1, 1, false);
  elements["expresso-videos"] = {
    textContent: '["data:video/webm;base64,BBBB"]',
  };
  medium.src = "";
  play(1, 1, false);
  assert.equal(medium.src, "data:video/webm;base64,AAAA");
});

// A deck with no video has no list. After the browser read the document, the
// player does not look again.
test("a player keeps the answer for a complete document with no list", () => {
  const medium = video();
  const elements = page("interactive", medium);
  const play = player("expresso-videos", "video");

  play(1, 1, false);
  elements["expresso-videos"] = list;
  play(1, 1, false);
  assert.equal(medium.src, "");
});
