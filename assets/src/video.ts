// The videos of the video element.
//
// The renderer writes no source into a `video` element, because the document
// holds a copy of each slide for the present view and one for each page of
// the handout view. It writes the number of the element into `data-video`,
// and each video once, as a data URI, into the element `expresso-videos`.
// `Expresso.Element.Video` makes them.
//
// `play` runs after each change of the state. A video plays only in the
// present view, while its slide shows and the element shows at the current
// step. A black screen, the menu and the overview pause it. A video gets its
// source the first time that it plays, and it starts again from the start
// when its slide shows again. Each other copy shows the poster under the
// `video` element, which has no source.

import type { WrittenVideos } from "./schema.ts";

// The videos, from the first call. `null` for a document with no element
// `expresso-videos`, which is a deck with no video.
let sources: WrittenVideos | null | undefined;

function read(): WrittenVideos | null {
  if (sources === undefined) {
    const element = document.getElementById("expresso-videos");
    // The renderer writes the list and this script into the same document, so
    // the script trusts the list, as it trusts the program.
    sources =
      element === null
        ? null
        : (JSON.parse(element.textContent ?? "[]") as WrittenVideos);
  }
  return sources;
}

// The part of a video element that this module uses. A test gives a fake.
export type Video = {
  dataset: DOMStringMap;
  paused: boolean;
  currentTime: number;
  src: string;
  closest: (selector: string) => Element | null;
  parentElement: Element | null;
  play: () => Promise<void>;
  pause: () => void;
};

// True when the element and each of its parents with an overlay show at the
// step. The renderer writes the steps of an overlay into `data-on`, such as
// `data-on="2 3"`, and an element without an overlay shows at each step.
export function shows(video: Video, step: number): boolean {
  let element: Element | null = video.closest("[data-on]");
  while (element !== null) {
    const steps = (element.getAttribute("data-on") ?? "").split(" ");
    if (!steps.includes(String(step))) {
      return false;
    }
    element = element.parentElement?.closest("[data-on]") ?? null;
  }
  return true;
}

// The videos that played, so a later call can pause them, and the slide of
// the last call.
const started = new Set<Video>();
let shown: number | null = null;

// Play each video of the slide that shows at the step, and pause each other
// video that played. `slide` is the slide of the present view, or null in
// the speaker view and in the handout view. `covered` is true while a black
// screen, the menu or the overview covers the slide: each video then pauses,
// and it goes on from the same time after. A move to another slide and back
// starts it again from the start.
export function play(
  slide: number | null,
  step: number,
  covered: boolean,
): void {
  const list = read();
  const section =
    list === null || slide === null || covered
      ? null
      : document.getElementById(`slide-${slide}`);
  const entered = slide !== shown;
  shown = slide;
  const playing = new Set<Video>();
  if (list !== null && section !== null) {
    const videos = section.querySelectorAll(
      "video[data-video]",
    ) as unknown as Iterable<Video>;
    for (const video of Array.from(videos)) {
      const source = list[Number(video.dataset.video)];
      if (source === undefined || !shows(video, step)) {
        continue;
      }
      if (video.src === "") {
        video.src = source;
      } else if (entered) {
        video.currentTime = 0;
      }
      playing.add(video);
      started.add(video);
      if (video.paused) {
        // A browser can refuse to play, such as a video that it cannot
        // decode. The poster then stays.
        video.play().catch(() => undefined);
      }
    }
  }
  for (const video of started) {
    if (!playing.has(video) && !video.paused) {
      video.pause();
    }
  }
}
