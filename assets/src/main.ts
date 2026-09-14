// The entry of the presenter. esbuild bundles this file and its imports into
// one script, and `Expresso.Renderer` writes that script into the document.
//
// The keys are `j` for the next step or slide, `k` for the previous step or
// slide, and `p` to change between the present view and the handout view.

import { initial, next } from "./state.ts";
import { apply, limits } from "./dom.ts";

let state = initial();
const deck = limits();

document.addEventListener("keydown", (event: KeyboardEvent) => {
  const changed = next(state, event.key, deck);
  if (changed !== state) {
    state = changed;
    apply(state, deck);
  }
});
