// The entry of the presenter. esbuild bundles this file and its imports into
// one script, and `Expresso.Renderer` writes that script into the document.
//
// `state.ts` gives the keys. The fragment of the address holds the slide and
// the step, so a reload shows the same step. A key with the Control, Alt or
// Meta modifier goes to the browser, because the browser uses these keys.

import { fromHash, initial, next, toHash } from "./state.ts";
import type { State } from "./state.ts";
import { apply, limits } from "./dom.ts";

const deck = limits();
let state = initial();

// Apply a new state, and write its fragment. `replaceState` adds no entry to
// the history, so the back button of the browser does not go through the steps.
function show(changed: State): void {
  if (changed === state) {
    return;
  }
  state = changed;
  apply(state, deck);
  history.replaceState(null, "", toHash(state));
}

show(fromHash(state, location.hash, deck));

document.addEventListener("keydown", (event: KeyboardEvent) => {
  if (event.ctrlKey || event.altKey || event.metaKey) {
    return;
  }
  const changed = next(state, event.key, deck);
  if (changed !== state) {
    event.preventDefault();
    show(changed);
  }
});

// The presenter can also type a fragment into the address bar.
window.addEventListener("hashchange", () => {
  show(fromHash(state, location.hash, deck));
});
