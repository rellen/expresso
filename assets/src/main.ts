// The entry of the presenter. esbuild bundles this file and its imports into
// one script, and `Expresso.Renderer` writes that script into the document.
//
// `state.ts` gives the keys. The fragment of the address holds the slide and
// the step, so a reload shows the same step. A key with the Control, Alt or
// Meta modifier goes to the browser, because the browser uses these keys.
//
// The key `s` opens the speaker view: the same document in a second window,
// with `?speaker` in the address. Each window sends its position to the other
// window with `postMessage`. `BroadcastChannel` is not reliable for a document
// that a browser opens from a file.
//
// `?all` in the address shows every step in the handout view and on paper, as
// the key `a` of the handout view does. A print or a PDF of such an address
// then gets every step with no key. The speaker view opens with the same
// address, so it also shows every step.

import { clock } from "./speaker.ts";
import {
  accepts,
  binding,
  follow,
  fromHash,
  initial,
  isMessage,
  message,
  next,
  stamp,
  toHash,
} from "./state.ts";
import type { State } from "./state.ts";
import { apply, limits, showsProgress, speakerPanel, text } from "./dom.ts";

const deck = limits();
const parameters = new URLSearchParams(location.search);
const isSpeaker = parameters.has("speaker");
let state: State = {
  ...initial(),
  view: isSpeaker ? "speaker" : "present",
  progress: showsProgress(),
  every: parameters.has("all"),
};

// The other window. The speaker view gets it from `window.opener`, and the
// present view gets it from `window.open`.
let partner: Window | null = isSpeaker ? window.opener : null;

// The timer of the speaker view starts at the first change of the slide or
// the step. The key `r` sets it back to the start.
let started: number | null = null;

function tick(): void {
  const elapsed = started === null ? 0 : Date.now() - started;
  text("speaker-timer", clock(elapsed));
}

// The time of the state of this window. `state.ts` gives the rule of the time.
let time = 0;

// Apply a new state, and write its fragment. `replaceState` adds no entry to
// the history, so the back button of the browser does not go through the
// steps. A change of this window goes to the other window with a new time. A
// change from the other window does not go back to it.
function show(changed: State, local = true): void {
  if (changed === state) {
    return;
  }
  const moved = changed.slide !== state.slide || changed.step !== state.step;
  state = changed;
  apply(state, deck);
  history.replaceState(null, "", toHash(state));
  if (local) {
    time = stamp(time, Date.now());
    if (partner !== null && !partner.closed) {
      partner.postMessage(message(state, time), "*");
    }
  }
  if (isSpeaker && moved && started === null) {
    started = Date.now();
    tick();
  }
}

// Open the speaker view, or show the window of the speaker view again. The
// name of the window makes sure that a second `s` opens no second window.
function openSpeaker(): void {
  const address = new URL(location.href);
  address.searchParams.set("speaker", "");
  address.hash = toHash(state);
  partner = window.open(address.href, "expresso-speaker");
}

if (isSpeaker) {
  document.title = `Speaker view: ${document.title}`;
  speakerPanel();
  tick();
  setInterval(tick, 250);
}

// The first application of the state gives the progress bar its width.
apply(state, deck);

show(fromHash(state, location.hash, deck));

document.addEventListener("keydown", (event: KeyboardEvent) => {
  if (event.ctrlKey || event.altKey || event.metaKey) {
    return;
  }
  // On a black screen or on the list of keys, `next` closes it first.
  const action =
    state.blank || state.help ? undefined : binding(state, event.key)?.action;
  if (action === "speaker") {
    event.preventDefault();
    state = { ...state, digits: "" };
    openSpeaker();
    return;
  }
  if (action === "reset") {
    event.preventDefault();
    started = null;
    tick();
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

// A message from the other window. A message from each other window has no
// effect. After a reload, the present view has no partner, and the next
// message of the speaker view makes the connection again.
window.addEventListener("message", (event: MessageEvent) => {
  const source = event.source as Window | null;
  if (partner === null && !isSpeaker && isMessage(event.data)) {
    partner = source;
  }
  if (partner === null || source !== partner || !isMessage(event.data)) {
    return;
  }
  if (!accepts(time, event.data.time, isSpeaker)) {
    return;
  }
  time = event.data.time;
  show(follow(state, event.data, deck), false);
});
