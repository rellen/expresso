// The entry of the presenter. esbuild bundles this file and its imports into
// one script, and `Expresso.Renderer` writes that script into the document.
//
// The renderer writes the program of the presenter into the document, and
// `interpreter.ts` runs it for each key, click and swipe. The program holds the
// commands of each key. The fragment of the address holds the slide and the
// step, so a reload shows the same step. A key with the Control, Alt or
// Meta modifier goes to the browser, because the browser uses these keys.
//
// The key `s` opens the speaker view: the same document in a second window,
// with `?speaker` in the address. Each window sends its position to the other
// window with `postMessage`. `BroadcastChannel` is not reliable for a document
// that a browser opens from a file.
//
// A click or a tap on the right two thirds of the window goes to the next
// step, and on the left third to the previous step. A swipe to the left goes
// to the next step, and a swipe to the right to the previous step. `side` and
// `swipe` in `state.ts` find the part of the window and the direction, and the
// program holds the commands of each. A click on a link, a button or a form
// field goes to the browser, and so does a click that ends a selection of text.
//
// The key `o` shows an overview of the slides in this window. A click or a
// tap on a slide of the overview goes to step 1 of that slide.
//
// The key `f` puts the document in full screen, or takes it out of full
// screen. The key `Escape` of the browser also takes it out.
//
// The renderer writes the list of the steps into the document, and `deck.ts`
// reads it. The state holds the index of the current step in that list.
//
// The deck option `duration` gives the length of the talk, and
// `?duration=` in the address replaces it. The speaker view then shows the
// time left under the timer, and the style sheet gives the pace its color.
//
// A move to a different slide in the present view runs a transition of the
// slide: `fade`, `slide` or `zoom`. The option of the slide or of the deck
// gives the kind, and `transition` in `interpreter.ts` holds the rules. A
// browser without the View Transitions API, and a reader who asks for reduced
// motion, get no transition.
//
// `?all` in the address shows every step in the handout view and on paper, as
// the key `a` of the handout view does. A print or a PDF of such an address
// then gets every step with no key. The speaker view opens with the same
// address, so it also shows every step.

import {
  follow,
  fromHash,
  helpMode,
  prevented,
  run,
  toHash,
  transition,
} from "./interpreter.ts";
import type { Event } from "./interpreter.ts";
import { commands } from "./program.ts";
import type { Builtin } from "./program.ts";
import { clock, left, pace, talkLength } from "./speaker.ts";
import {
  accepts,
  current,
  isMessage,
  message,
  side,
  stamp,
  swipe,
} from "./state.ts";
import type { State } from "./state.ts";
import {
  animate,
  apply,
  deck as readDeck,
  program as readProgram,
  showsProgress,
  speakerPanel,
  text,
  timeLeft,
} from "./dom.ts";

const deck = readDeck();
const program = readProgram();
const parameters = new URLSearchParams(location.search);
const isSpeaker = parameters.has("speaker");
let state: State = {
  ...program.state,
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

// The length of the talk, from the list of the steps or the address
// parameter `?duration=`. The speaker view opens with the address of the
// present view, so it gets the same parameter.
const total = talkLength(deck.duration, parameters.get("duration"));

// Write the timer, and the time left and the pace of a talk with a length.
function tick(): void {
  const elapsed = started === null ? 0 : Date.now() - started;
  text("speaker-timer", clock(elapsed));
  if (total !== null) {
    const done = current(state, deck)?.done ?? 0;
    timeLeft(left(elapsed, total), pace(elapsed, total, done));
  }
}

// The time of the state of this window. `state.ts` gives the rule of the time.
let time = 0;

// Apply a new state, and write its fragment. `replaceState` adds no entry to
// the history, so the back button of the browser does not go through the
// steps. A change of this window goes to the other window with a new time. A
// change from the other window does not go back to it. A message holds only
// the position and the black screen. A change to other data, such as the
// overview, sends no message.
function show(changed: State, local = true): void {
  if (changed === state) {
    return;
  }
  const moved = changed.index !== state.index;
  const sent = moved || changed.blank !== state.blank;
  const change = transition(state, changed, deck);
  state = changed;
  // The browser runs the update of a transition later. The update then reads
  // the state of that time, so a fast second key does not show an old state.
  animate(change, () => apply(state, deck, helpMode(program, state)));
  history.replaceState(null, "", toHash(state, deck));
  if (local && sent) {
    time = stamp(time, Date.now());
    if (partner !== null && !partner.closed) {
      partner.postMessage(message(state, deck, time), "*");
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
  address.hash = toHash(state, deck);
  partner = window.open(address.href, "expresso-speaker");
}

// Put the document in full screen, or take it out. A browser can refuse, for
// example in a frame, and the document then stays as it is.
function fullscreen(): void {
  if (document.fullscreenElement) {
    document.exitFullscreen().catch(() => undefined);
  } else if (document.fullscreenEnabled) {
    document.documentElement.requestFullscreen().catch(() => undefined);
  }
}

if (isSpeaker) {
  document.title = `Speaker view: ${document.title}`;
  speakerPanel();
  tick();
  setInterval(tick, 250);
}

// The first application of the state gives the progress bar its width.
apply(state, deck, helpMode(program, state));

show(fromHash(state, location.hash, deck));

// Call a built-in function of the program.
function call(builtin: Builtin): void {
  switch (builtin) {
    case "open_speaker":
      openSpeaker();
      break;
    case "fullscreen":
      fullscreen();
      break;
    case "reset_timer":
      started = null;
      tick();
      break;
  }
}

// Run one event with the program. The browser does not use a key that changes
// the state or calls a built-in function. The browser uses each other key, so
// the arrow keys and the space bar scroll the pages of the handout view.
function handle(input: Event, event?: KeyboardEvent): void {
  const result = run(program, deck, state, input);
  if (prevented(state, result)) {
    event?.preventDefault();
  }
  show(result.state);
  for (const builtin of result.effects) {
    call(builtin);
  }
}

document.addEventListener("keydown", (event: KeyboardEvent) => {
  if (event.ctrlKey || event.altKey || event.metaKey) {
    return;
  }
  handle({ kind: "key", key: event.key }, event);
});

// The elements that use a click themselves.
const INTERACTIVE =
  "a, button, input, select, textarea, label, summary, audio, video, iframe, [contenteditable]";

// True for a click that goes to the browser: a click with a modifier or with
// a button other than the main button, a click on an interactive element, and
// a click that ends a selection of text.
function ignores(event: MouseEvent): boolean {
  if (event.button !== 0) {
    return true;
  }
  if (event.ctrlKey || event.altKey || event.metaKey || event.shiftKey) {
    return true;
  }
  const target = event.target as Element | null;
  if (target?.closest?.(INTERACTIVE)) {
    return true;
  }
  return window.getSelection?.()?.isCollapsed === false;
}

// The commands of the page of the overview under a click, or null. The
// renderer writes them on the page of the last step of each slide.
function element(event: MouseEvent) {
  const target = event.target as Element | null;
  const page = target?.closest?.(".handout-page[data-commands]") as
    HTMLElement | null | undefined;
  const text = page?.dataset.commands;
  return text === undefined ? null : commands(text, program);
}

document.addEventListener("click", (event: MouseEvent) => {
  if (ignores(event)) {
    return;
  }
  handle({
    kind: "click",
    region: side(event.clientX, window.innerWidth),
    element: element(event),
  });
});

// The start of a movement of one finger, or null. A second finger, as for a
// zoom, stops the swipe.
let touched: { x: number; y: number } | null = null;

document.addEventListener(
  "touchstart",
  (event: TouchEvent) => {
    const finger = event.touches[0];
    touched =
      event.touches.length === 1 && finger !== undefined
        ? { x: finger.clientX, y: finger.clientY }
        : null;
  },
  { passive: true },
);

document.addEventListener(
  "touchend",
  (event: TouchEvent) => {
    const finger = event.changedTouches[0];
    const start = touched;
    touched = null;
    if (start === null || finger === undefined) {
      return;
    }
    const direction = swipe(finger.clientX - start.x, finger.clientY - start.y);
    if (direction !== undefined) {
      handle({ kind: "swipe", direction });
    }
  },
  { passive: true },
);

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
