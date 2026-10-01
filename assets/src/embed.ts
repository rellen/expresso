// The frames of the embed element.
//
// The renderer writes no source into a frame, because the document holds a
// copy of each slide for the present view and one for each page of the
// handout view. It writes the number of the element into `data-embed`, and
// the source of each element once into the element `expresso-embeds`.
// `Expresso.Element.Embed` makes them. This module gives a frame of the
// present view its source when its slide shows, so each page loads one time.
// The page then stays loaded, and a move back to the slide shows it as it is.
//
// The fallback image shows under the frame while the page loads. After the
// load, it gets `hidden`, so a screen reader reads the title of the frame
// only one time.
//
// A browser with no network loads no address, so the fallback stays, and
// not the error page of the browser. `main.ts` calls `load` again at the
// event `online`. A page that the network does not deliver still gives the
// error page, because a deck cannot read a page of a different origin.

import type { WrittenEmbeds } from "./schema.ts";

// The sources, from the first call. `null` for a document with no element
// `expresso-embeds`, which is a deck with no embed.
let sources: WrittenEmbeds | null | undefined;

function read(): WrittenEmbeds | null {
  if (sources === undefined) {
    const element = document.getElementById("expresso-embeds");
    // The renderer writes the list and this script into the same document, so
    // the script trusts the list, as it trusts the program.
    sources =
      element === null
        ? null
        : (JSON.parse(element.textContent ?? "[]") as WrittenEmbeds);
  }
  return sources;
}

// The attribute of a frame for a source, and its value: `src` for an address,
// and `srcdoc` for the text of a local file.
export function attribute(
  source: WrittenEmbeds[number],
): ["src" | "srcdoc", string] {
  return [source.kind, source.value];
}

// Give each frame of a slide of the present view its source, one time.
export function load(slide: number): void {
  const list = read();
  const section =
    list === null ? null : document.getElementById(`slide-${slide}`);
  if (list === null || section === null) {
    return;
  }
  const frames =
    section.querySelectorAll<HTMLIFrameElement>("iframe[data-embed]");
  for (const frame of Array.from(frames)) {
    const source = list[Number(frame.dataset.embed)];
    if (frame.dataset.loaded !== undefined || source === undefined) {
      continue;
    }
    if (source.kind === "src" && navigator.onLine === false) {
      continue;
    }
    frame.dataset.loaded = "";
    frame.addEventListener(
      "load",
      () => {
        const fallback =
          frame.parentElement?.querySelector<HTMLElement>(".embed-fallback");
        if (fallback) {
          fallback.hidden = true;
        }
      },
      { once: true },
    );
    const [name, value] = attribute(source);
    frame.setAttribute(name, value);
  }
}
