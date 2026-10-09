// The media of the video element and of the audio element.
//
// The renderer writes no source into a `video` or an `audio` element, because
// the document holds a copy of each slide for the present view and one for
// each page of the handout view. It writes the number of the element into a
// data attribute, such as `data-video`, and each file once, as a data URI,
// into a JSON element, such as `expresso-videos`. `Expresso.Media` makes them.
//
// A player runs after each change of the state. A medium plays only in the
// present view, while its slide shows and the element shows at the current
// step. A black screen, the menu and the overview pause it. A medium gets its
// source the first time that it plays, and it starts again from the start
// when its slide shows again. `video.ts` and `audio.ts` make a player each.

// The part of a media element that this module uses. A test gives a fake.
export type Media = {
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
export function shows(media: Media, step: number): boolean {
  let element: Element | null = media.closest("[data-on]");
  while (element !== null) {
    const steps = (element.getAttribute("data-on") ?? "").split(" ");
    if (!steps.includes(String(step))) {
      return false;
    }
    element = element.parentElement?.closest("[data-on]") ?? null;
  }
  return true;
}

// The function that plays the media of one kind. `slide` is the slide of the
// present view, or null in the speaker view and in the handout view.
// `covered` is true while a black screen, the menu or the overview covers the
// slide: each medium then pauses, and it goes on from the same time after. A
// move to another slide and back starts it again from the start.
export type Player = (
  slide: number | null,
  step: number,
  covered: boolean,
) => void;

// Make the player of one kind of media: the id of its JSON element, such as
// `expresso-videos`, and the name of its data attribute, such as `video`.
export function player(list: string, key: string): Player {
  // The data URIs, from the first call. `null` for a document with no such
  // element, which is a deck with none of this kind.
  let sources: readonly string[] | null | undefined;
  // The media that played, so a later call can pause them, and the slide of
  // the last call.
  const started = new Set<Media>();
  let shown: number | null = null;

  function read(): readonly string[] | null {
    if (sources === undefined) {
      const element = document.getElementById(list);
      // The renderer writes the list and this script into the same document,
      // so the script trusts the list, as it trusts the program.
      sources =
        element === null
          ? null
          : (JSON.parse(element.textContent ?? "[]") as readonly string[]);
    }
    return sources;
  }

  return (slide, step, covered) => {
    const files = read();
    const section =
      files === null || slide === null || covered
        ? null
        : document.getElementById(`slide-${slide}`);
    const entered = slide !== shown;
    shown = slide;
    const playing = new Set<Media>();
    if (files !== null && section !== null) {
      const media = section.querySelectorAll(
        `[data-${key}]`,
      ) as unknown as Iterable<Media>;
      for (const medium of Array.from(media)) {
        const source = files[Number(medium.dataset[key])];
        if (source === undefined || !shows(medium, step)) {
          continue;
        }
        if (medium.src === "") {
          medium.src = source;
        } else if (entered) {
          medium.currentTime = 0;
        }
        playing.add(medium);
        started.add(medium);
        if (medium.paused) {
          // A browser can refuse to play: a file that it cannot decode, or
          // sound before the first key or click of the presenter. The medium
          // then stays paused, and the next change of the state tries again.
          medium.play().catch(() => undefined);
        }
      }
    }
    for (const medium of started) {
      if (!playing.has(medium) && !medium.paused) {
        medium.pause();
      }
    }
  };
}
