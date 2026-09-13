// The entry of the presenter. esbuild bundles this file and its imports into
// one script, and `Expresso.Renderer` writes that script into the document.
//
// The keys are `j` for the next slide, `k` for the previous slide, and `p` to
// show each slide for a printer.

import { initial, next } from "./state.ts";
import { apply, limits, showAll } from "./dom.ts";

let state = initial();
const deck = limits();

document.addEventListener("keydown", (event: KeyboardEvent) => {
  if (event.key === "p") {
    showAll(deck);
    return;
  }

  const changed = next(state, event.key, deck);
  if (changed !== state) {
    state = changed;
    apply(state, deck);
  }
});
