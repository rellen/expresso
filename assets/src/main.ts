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
// The key `t` shows the other variant of a theme with a light and a dark
// variant, in the two windows. `?scheme=light` or `?scheme=dark` in the
// address chooses a variant at the load. `scheme.ts` gives the rules.
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
//
// A frame of the embed element gets its source when its slide shows in the
// present view, after the load of the document. The speaker view and the
// handout view load no page. `embed.ts` gives the rules.
//
// A video of the video element plays while its slide and its step show in the
// present view, and a black screen, the menu and the overview pause it. The
// speaker view and the handout view show its poster. `video.ts` gives the
// rules. A sound of the audio element plays with the same rules, and
// `audio.ts` gives the rest.
//
// A number of a chart with the `count` option counts from one frame to the
// next after each change of the step. `chart.ts` gives the rules.
//
// The key `l` turns the laser pointer on and off. While it is on, a dot goes
// with the mouse or with a finger, in the two windows, and a click or a swipe
// does not change the step. `laser.ts` gives the rules.
//
// The key `x` turns the drawing on and off. While it is on, a drag of the
// mouse or of a finger draws a line on the slide, in the two windows. The key
// `h` changes the pen to the highlighter, and the key `c` removes the drawing.
// A change of the slide also removes it. `drawing.ts` gives the rules.
//
// A click with the Alt key makes the part of the slide under the mouse fill
// the window, in the two windows, and the next such click shows the full
// slide again. The key `z` turns on a zoom where a click with no key does the
// same. `Escape` and a change of the step show the full slide. `zoom.ts`
// gives the rules.
//
// The option `advance` of a slide or of the deck gives each step a time. The
// present view goes to the next step when the time ends, and the speaker
// view shows the time left. The key `a` stops and starts the clock, and
// `?paused` in the address stops it at the load. `advance.ts` gives the
// rules.
//
// `?check` in the address of the present view runs the layout check after the
// load of the document and of its fonts. The check shows each step, finds the
// elements that go past an edge of the window and the lines of code that
// break, and writes a report into the document. `layout.ts` gives the rules.
// `?check=a11y` then runs axe-core at each step and in each view, when the
// document holds it. `check.ts` gives the rules, and the result of the two
// checks for `mix expresso --check`.

import {
  follow,
  fromHash,
  prevented,
  run,
  toHash,
  transition,
} from "./interpreter.ts";
import type { Event } from "./interpreter.ts";
import { commands } from "./program.ts";
import type { Builtin } from "./program.ts";
import { load as loadEmbeds } from "./embed.ts";
import { play as playVideos } from "./video.ts";
import { play as playAudios } from "./audio.ts";
import { count } from "./chart.ts";
import { forget, place } from "./move.ts";
import { modeOf, pairs } from "./morph.ts";
import type { Pair } from "./morph.ts";
import { search } from "./search.ts";
import { audit, report, sentence } from "./layout.ts";
import { accessibility, engine, write } from "./check.ts";
import { measure } from "./background.ts";
import { clock, left, pace, talkLength } from "./speaker.ts";
import {
  due,
  left as stepTime,
  runs,
  start as startClock,
  text as stepText,
  update as updateClock,
} from "./advance.ts";
import {
  accepts,
  current,
  isMessage,
  isRequest,
  limit,
  message,
  request,
  side,
  stamp,
  swipe,
  synced,
} from "./state.ts";
import type { State } from "./state.ts";
import {
  animate,
  apply,
  announce,
  announceOverview,
  deck as readDeck,
  elementBox,
  isSlideBox,
  laser,
  link,
  mediaPlays,
  program as readProgram,
  scheme,
  showDrawing,
  showScheme,
  showZoom,
  slideBox,
  stepLeft,
  text,
  timeLeft,
} from "./dom.ts";
import {
  drawing,
  extend,
  isDrawing,
  message as drawingMessage,
  nearest,
  start as startLine,
  tool,
} from "./drawing.ts";
import type { Line } from "./drawing.ts";
import {
  isPointer,
  placeIn,
  placeOf,
  pointer,
  pointing,
  pointOf,
} from "./laser.ts";
import type { Place } from "./laser.ts";
import {
  isZoom,
  message as zoomMessage,
  scaleOf,
  target as zoomTarget,
  zoomable,
  zooming,
} from "./zoom.ts";
import type { Area } from "./zoom.ts";
import { fromAddress, next } from "./scheme.ts";
import { restore as restoreAssets } from "./assets.ts";
import { COMMAND_HOLDERS } from "./schema.ts";

// Each view gets its copy of the large files before the first render.
restoreAssets(document);

const deck = readDeck();
const program = readProgram();
const parameters = new URLSearchParams(location.search);
const isSpeaker = parameters.has("speaker");
// The program holds the first state, with the `progress` of the deck. The
// address gives the view, `every` and `paused`.
let state: State = {
  ...program.state,
  view: isSpeaker ? "speaker" : "present",
  every: parameters.has("all"),
  paused: parameters.has("paused"),
};

// The other window. The speaker view gets it from `window.opener`, and the
// present view gets it from `window.open`.
let partner: Window | null = isSpeaker ? window.opener : null;

// The timer of the speaker view starts at the first change of the slide or
// the step after the load. The step of the address at the load is not such a
// change, so a speaker view that opens at slide 3 also waits for a key. The
// key `r` sets the timer back to the start.
let started: number | null = null;

// True after the first state of the address shows.
let loaded = false;

// The lines of the drawing of the slide that shows, and the line that the
// pointer draws now, or null. The first state of the address shows before
// each later part of this file, so the two values are here.
let lines: readonly Line[] = [];
let stroke: Line | null = null;

// The part of the slide that fills the window, or null for the full slide.
// The first state of the address shows before each later part of this file,
// so the value is here.
let zoomed: Area | null = null;

// The clock of the step that shows. `advance.ts` gives the rules.
let stepClock = startClock(state.index, runs(state), Date.now());

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
  const remaining = stepTime(stepClock, current(state, deck), Date.now());
  stepLeft(stepText(remaining, runs(state)));
}

// Go to the next step when the time of the step ended. The present view
// calls this function four times each second, so a clock that the computer
// stopped for some time, such as in a window that does not show, also
// moves. The move is the move of a fragment of the address, so it gives each
// field of the option `reset` its first value, as each change of the step
// does. A step does not end while a video or a sound of its slide plays, so
// a clip that is longer than the time of its step plays to its end.
function advance(): void {
  const entry = current(state, deck);
  const next = entry?.next == null ? undefined : deck.steps[entry.next];
  if (
    entry !== undefined &&
    next !== undefined &&
    due(stepClock, entry, Date.now()) &&
    !mediaPlays(entry.slide)
  ) {
    show(fromHash(program, state, `#${next.slide}.${next.step}`, deck));
  }
}

// The time of the state of this window. `state.ts` gives the rule of the time.
let time = 0;

// Send the position, the fields of the option `sync` and the variant of the
// theme to the other window, with a new time.
function send(): void {
  time = stamp(time, Date.now());
  if (partner !== null && !partner.closed) {
    partner.postMessage(message(program, state, deck, time, scheme()), "*");
  }
}

// The pairs of the morph from the slide of one state to the slide of another.
// `assets/src/morph.ts` gives the rules.
function morphs(before: State, after: State): Pair[] {
  const from = current(before, deck)?.slide;
  const to = current(after, deck)?.slide;
  const old =
    from === undefined ? null : document.getElementById(`slide-${from}`);
  const next = to === undefined ? null : document.getElementById(`slide-${to}`);
  if (from === undefined || to === undefined || old === null || next === null) {
    return [];
  }
  return pairs(old, next, modeOf(old, next, from, to));
}

// Apply a new state, and write its fragment. `replaceState` adds no entry to
// the history, so the back button of the browser does not go through the
// steps. A change of this window goes to the other window. A change from the
// other window and the state of the address at the load do not go to it. A
// message holds only the position, the fields of the option `sync` and the
// variant of the theme. A change to other data, such as the overview, sends no
// message.
function show(changed: State, local = true): void {
  if (changed === state) {
    return;
  }
  const before = state;
  const moved = changed.index !== state.index;
  const slideChanged =
    current(changed, deck)?.slide !== current(state, deck)?.slide;
  const sent = synced(program, state, changed);
  const change = transition(state, changed, deck);
  const pairs = change === null ? [] : morphs(state, changed);
  state = changed;
  stepClock = updateClock(stepClock, state.index, runs(state), Date.now());
  // The browser runs the update of a transition later. The update then reads
  // the state of that time, so a fast second key does not show an old state.
  animate(
    change,
    () => {
      apply(state, deck, program);
      count();
      place();
    },
    pairs,
  );
  if (moved) {
    announce(state, deck, slideChanged);
  }
  // The overview changes `selected` and not the step, so a screen reader
  // hears the selected slide at each change of it. A close of the overview
  // with no move gives the position again.
  if (
    state.overview &&
    (!before.overview || state.selected !== before.selected)
  ) {
    announceOverview(state.selected, !before.overview);
  } else if (before.overview && !state.overview && !moved) {
    announce(state, deck, true);
  }
  history.replaceState(null, "", toHash(state, deck));
  if (local && sent) {
    send();
  }
  // The dot of the laser pointer goes away when the pointer turns off, and
  // while a view with no slide covers the slide. The next move of the mouse
  // shows it again.
  if (!pointing(state)) {
    laser(null);
  }
  // The drawing belongs to the slide that shows, so a change of the slide
  // removes it. The other window removes its own drawing at the same change.
  // A change with no drawing mode ends the line that the pointer draws.
  if (slideChanged) {
    lines = [];
    stroke = null;
  } else if (!drawing(state)) {
    finishStroke();
  }
  // The zoom belongs to the step that shows, so a change of the step shows
  // the full slide again, and so does the end of the zoom of the key `z`.
  // The other window gets the same change of the state, so it needs no
  // message of the zoom.
  if (moved || (before.zoom && !state.zoom)) {
    zoomTo(null, false);
  }
  showDrawing(shownLines(), state.view);
  if (document.readyState === "complete") {
    embeds();
  }
  videos();
  if (isSpeaker && loaded && moved && started === null) {
    started = Date.now();
    tick();
  }
}

// Load the pages of the current slide. The present view of this window shows
// the slide, so the speaker view loads no page.
function embeds(): void {
  const entry = current(state, deck);
  if (!isSpeaker && state.view === "present" && entry !== undefined) {
    loadEmbeds(entry.slide);
  }
}

// Play the videos and the sounds of the current slide. Only the present view
// of this window plays them, so the speaker view and the handout view show
// the poster of a video and play no sound. `media.ts` gives the rules.
function videos(): void {
  const entry = current(state, deck);
  const present = !isSpeaker && state.view === "present";
  const slide = present && entry !== undefined ? entry.slide : null;
  const covered = state.blank || state.menu || state.overview;
  playVideos(slide, entry?.step ?? 1, covered);
  playAudios(slide, entry?.step ?? 1, covered);
}

// Open the speaker view, or show the window of the speaker view again. The
// name of the window makes sure that a second `s` opens no second window. The
// address gives the variant of the theme that this window shows. A second `s`
// does not change the address of an open speaker view, because a new address
// loads the window again, and its timer then starts again at 0:00.
function openSpeaker(): void {
  if (partner !== null && !partner.closed) {
    partner.focus();
    return;
  }
  const address = new URL(location.href);
  address.searchParams.set("speaker", "");
  const chosen = scheme();
  if (chosen === null) {
    address.searchParams.delete("scheme");
  } else {
    address.searchParams.set("scheme", chosen);
  }
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

// Show the other variant of a theme with a light and a dark variant, in this
// window and in the other window. A document with one variant has no
// `data-variants`, and the key then changes nothing.
function switchScheme(): void {
  if (!document.documentElement.hasAttribute("data-variants")) {
    return;
  }
  const dark =
    window.matchMedia?.("(prefers-color-scheme: dark)").matches === true;
  showScheme(next(scheme(), dark));
  send();
}

// The address can choose a variant, such as `?scheme=dark`. The speaker view
// gets the variant of the present view in this way.
showScheme(fromAddress(parameters.get("scheme")));

if (isSpeaker) {
  document.title = `Speaker view: ${document.title}`;
  tick();
  setInterval(tick, 250);
}

// The present view moves the steps of a deck with a time. The layout check
// shows each step itself, so it runs with no clock.
if (
  !isSpeaker &&
  !parameters.has("check") &&
  deck.steps.some((step) => step.advance !== null)
) {
  setInterval(advance, 250);
}

// The first application of the state gives the progress bar its width. The
// numbers of a chart with the `count` option get the values of their step.
apply(state, deck, program);
count();
place();

// A part of a formula with `move_to` moves by a distance that `move.ts`
// measures. A new size of the window and a font that loads change the
// distance.
window.addEventListener("resize", place);
if ("fonts" in document) {
  const again = (): void => {
    forget();
    place();
  };
  document.fonts.addEventListener("loadingdone", again);
  void document.fonts.ready.then(again);
}

// The state of the address sends no message. Before this rule, a reload of
// the speaker view sent its old state, and the present view lost its black
// screen. The speaker view asks the present view for its state, and the
// answer of the present view moves the speaker view.
show(fromHash(program, state, location.hash, deck), false);
loaded = true;
if (isSpeaker && partner !== null && !partner.closed) {
  partner.postMessage(request(), "*");
}

// `show` does nothing when the fragment gives no new step, so the video of the
// first step needs its own call.
videos();

// The pages load after the document, so the slides show at once. A page that
// loads slowly then does not hold the load of the document.
if (document.readyState === "complete") {
  embeds();
} else {
  window.addEventListener("load", embeds, { once: true });
}
window.addEventListener("online", embeds);

// The layout check measures each step, and then it shows the current step
// again. The images of a document load after the script, so the check waits
// for the load of the document. An error of the check shows the current step
// again and goes to the console, as each problem of the check does.
function check(): void {
  document.fonts.ready
    .then(async () => {
      const show = (index: number): void => {
        apply({ ...state, index }, deck, program);
        place();
      };
      const problems = audit(deck.steps, show);
      apply(state, deck, program);
      report(problems);
      const axe = parameters.get("check") === "a11y" ? engine() : undefined;
      const findings =
        axe === undefined
          ? null
          : await accessibility(
              deck.steps,
              show,
              views(),
              axe,
              undefined,
              measure,
            );
      apply(state, deck, program);
      write({
        width: window.innerWidth,
        height: window.innerHeight,
        layout: problems.map(sentence),
        accessibility: findings,
      });
    })
    .catch((reason: unknown) => {
      apply(state, deck, program);
      console.error("Expresso layout check failed:", reason);
    });
}

// The views that the accessibility check reads after the steps, each with
// the function that shows it.
function views(): (readonly [string, () => void])[] {
  const open = (changed: State) => (): void => apply(changed, deck, program);
  return [
    ["The present view", open(state)],
    ["The menu", open({ ...state, menu: true })],
    ["The list of keys", open({ ...state, help: true })],
    ["The overview", open({ ...state, overview: true })],
    ["The handout view", open({ ...state, view: "handout" })],
  ];
}

if (parameters.has("check") && !isSpeaker) {
  if (document.readyState === "complete") {
    check();
  } else {
    window.addEventListener("load", check, { once: true });
  }
}

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
    case "switch_scheme":
      switchScheme();
      break;
    case "clear_drawing":
      lines = [];
      stroke = null;
      redraw();
      break;
    case "zoom_out":
      zoomTo(null);
      break;
    default: {
      // The type check finds each built-in function that has no branch. The
      // program comes from the renderer with no examination, so a function
      // that the script does not know stops the script at once.
      const unknown: never = builtin;
      throw new Error(
        `An unknown built-in function: ${JSON.stringify(unknown)}`,
      );
    }
  }
}

// Run one event with the program. The browser does not use a key or a click
// that changes the state or calls a built-in function. The browser uses each
// other key, so the arrow keys and the space bar scroll the pages of the
// handout view. The browser also follows a link of the `goto` option that the
// program does not use, such as in the handout view.
function handle(input: Event, event?: UIEvent): void {
  const result = run(program, deck, state, input);
  if (prevented(state, result)) {
    event?.preventDefault();
  }
  show(result.state);
  for (const builtin of result.effects) {
    call(builtin);
  }
}

// A key with Control, Alt or Meta goes to the browser, and so does a key in a
// field of text, such as the search of the list of keys. A key on an element
// inside the list of keys also goes to the browser, so `Tab` moves the focus
// to a section, and `Enter` or the space bar opens it. `Escape` in the list
// closes the dialog, and the browser then sends `close`.
document.addEventListener("keydown", (event: KeyboardEvent) => {
  if (event.ctrlKey || event.altKey || event.metaKey) {
    return;
  }
  const target = event.target as Element | null;
  if (target?.closest?.(EDITABLE) || target?.closest?.("#help")) {
    return;
  }
  handle({ kind: "key", key: event.key }, event);
});

const EDITABLE = "input, textarea, select, [contenteditable]";

// The list of keys is a `dialog`. The browser closes it at `Escape` and at a
// click outside it, and the state then follows. The search runs at each
// change of the text.
const keys = document.getElementById("help");
keys?.addEventListener("close", () => {
  if (state.help) {
    show({ ...state, help: false });
  }
});
keys?.addEventListener("input", (event: globalThis.Event) => {
  const field = event.target as HTMLInputElement | null;
  if (field?.id === "help-filter") {
    search(keys, field.value);
  }
});

// The three kinds of element that hold commands: a link of the `goto` option,
// a page of the overview and a row of the menu. `schema.ts` gives them.
const { link: LINK, page: PAGE, row: ROW } = COMMAND_HOLDERS;

// The elements that use a click themselves.
const INTERACTIVE =
  "a, button, input, select, textarea, label, summary, audio, video, iframe, [contenteditable]";

// True for a click that goes to the browser: a click with a modifier or with
// a button other than the main button, a click on an interactive element, and
// a click that ends a selection of text. A link with commands is not such an
// element, because the program decides what a click on it does.
function ignores(event: MouseEvent): boolean {
  if (event.button !== 0) {
    return true;
  }
  if (event.ctrlKey || event.altKey || event.metaKey || event.shiftKey) {
    return true;
  }
  const target = event.target as Element | null;
  // A click inside the list of keys goes to the browser. A click on its
  // backdrop has the dialog itself as its target, and it closes the list.
  const list = target?.closest?.("#help");
  if (list && list !== target) {
    return true;
  }
  const interactive = target?.closest?.(INTERACTIVE);
  if (interactive && !interactive.matches(LINK)) {
    return true;
  }
  return window.getSelection?.()?.isCollapsed === false;
}

// The commands of the nearest element under a click that holds commands, or
// null. The renderer writes them on the page of the last step of each slide,
// for the overview, and on each row of the menu. A link of the `goto` option
// holds only its number in `data-link`, and the renderer writes the commands
// of each link into the element `expresso-links`. Thus the HTML of a deck can
// give a link no commands that the compiler did not make. The script reads
// commands only from these three kinds of element. The selectors examine only
// the tag, the class, the id and the attribute, so these names are reserved.
// In the overview, the style sheet stops a click on the content of a page, so
// the click finds the page and not a link on it.
function element(event: MouseEvent) {
  const target = event.target as Element | null;
  const holder = target?.closest?.(`${LINK}, ${PAGE}, ${ROW}`) as
    HTMLElement | null | undefined;
  if (holder?.matches(LINK)) {
    return link(holder.dataset.link);
  }
  const text = holder?.dataset.commands;
  return text === undefined ? null : commands(text);
}

// Put the dot of the laser pointer at a place on the slide, or hide it. The
// place comes from the mouse of this window, or from the other window.
function point(place: Place | null): void {
  const box = slideBox(state.view);
  const shown = place !== null && box !== null && pointing(state);
  laser(shown ? pointOf(place, box) : null);
}

// Move the dot to the mouse or to the finger, and send its place to the
// other window. The place is a part of the slide, so the dot is on the same
// part of the slide in a window of a different size.
function track(event: PointerEvent): void {
  if (!pointing(state)) {
    return;
  }
  trackPlace(placeIn(event.clientX, event.clientY, slideBox(state.view)));
}

function trackPlace(place: Place | null): void {
  point(place);
  if (partner !== null && !partner.closed) {
    partner.postMessage(pointer(place), "*");
  }
}

function shownLines(): readonly Line[] {
  return stroke === null ? lines : [...lines, stroke];
}

// Show the drawing in this window, and send it to the other window.
function redraw(): void {
  showDrawing(shownLines(), state.view);
  if (partner !== null && !partner.closed) {
    partner.postMessage(drawingMessage(shownLines()), "*");
  }
}

// Put the line that the pointer draws with the lines of the drawing.
function finishStroke(): void {
  if (stroke !== null) {
    lines = [...lines, stroke];
    stroke = null;
  }
}

// Start a line at the pointer, when the drawing is on and the pointer is on
// the slide. A press with the Alt key is the start of a click that zooms, so
// it draws no line.
function startStroke(event: PointerEvent): void {
  if (!drawing(state) || event.button !== 0 || event.altKey) {
    return;
  }
  const place = placeIn(event.clientX, event.clientY, slideBox(state.view));
  if (place !== null) {
    finishStroke();
    stroke = startLine(tool(state), place);
    redraw();
  }
}

// Add the place of the pointer to the line. A drag past an edge of the slide
// continues along that edge.
function continueStroke(event: PointerEvent): void {
  const box = slideBox(state.view);
  if (stroke === null || box === null) {
    return;
  }
  const longer = extend(stroke, nearest(event.clientX, event.clientY, box));
  if (longer !== stroke) {
    stroke = longer;
    redraw();
  }
}

document.addEventListener("pointermove", (event: PointerEvent) => {
  track(event);
  continueStroke(event);
});
document.addEventListener("pointerdown", (event: PointerEvent) => {
  track(event);
  startStroke(event);
});
// The end of a drag. The line stays in the drawing of the slide.
document.addEventListener("pointerup", finishStroke);
document.addEventListener("pointercancel", finishStroke);
// The box of the slide changes with the size of the window.
window.addEventListener("resize", () => {
  showDrawing(shownLines(), state.view);
});

// Show an area of the slide, or the full slide with null. A change from this
// window goes to the other window. The drawing is on the box of the slide,
// so it moves with the slide.
function zoomTo(area: Area | null, local = true): void {
  if (area === zoomed) {
    return;
  }
  zoomed = area;
  showZoom(area === null ? null : scaleOf(area));
  showDrawing(shownLines(), state.view);
  if (local && partner !== null && !partner.closed) {
    partner.postMessage(zoomMessage(area), "*");
  }
}

// True for a click that zooms: a click of the main button with the Alt key,
// or with no key while the zoom is on. The window must show a slide.
function zooms(event: MouseEvent): boolean {
  if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey) {
    return false;
  }
  return event.altKey ? zoomable(state) : zooming(state);
}

// Zoom to the element of the slide under a click, or around the point of a
// click outside each element. A click on a zoomed slide shows the full slide
// again. A click outside the slide, such as on the notes of the speaker
// view, does nothing.
function zoomAt(event: MouseEvent): void {
  const slide = slideBox(state.view);
  const place = placeIn(event.clientX, event.clientY, slide);
  if (slide === null || place === null) {
    return;
  }
  // The browser saves the target of a link at a click with the Alt key.
  event.preventDefault();
  if (zoomed !== null) {
    zoomTo(null);
    return;
  }
  const element = elementBox(event.target as Element | null);
  zoomTo(zoomTarget(place, element, slide));
}

// The transition of the zoom moves the slide for some time. The drawing is
// on the box of the slide, so it follows that box at each frame until the
// transition ends.
let moving = false;

function followSlide(): void {
  showDrawing(shownLines(), state.view);
  if (moving) {
    requestAnimationFrame(followSlide);
  }
}

document.addEventListener("transitionrun", (event: TransitionEvent) => {
  const slide = isSlideBox(event.target, state.view);
  if (slide && event.propertyName === "transform" && !moving) {
    moving = true;
    requestAnimationFrame(followSlide);
  }
});

function settle(event: TransitionEvent): void {
  if (isSlideBox(event.target, state.view)) {
    moving = false;
    showDrawing(shownLines(), state.view);
  }
}

document.addEventListener("transitionend", settle);
document.addEventListener("transitioncancel", settle);

// The mouse left the window, so the dot goes away in the two windows. A
// finger that leaves the screen keeps the dot at its place.
document.addEventListener("pointerout", (event: PointerEvent) => {
  if (
    pointing(state) &&
    event.pointerType === "mouse" &&
    event.relatedTarget === null
  ) {
    trackPlace(null);
  }
});

document.addEventListener("click", (event: MouseEvent) => {
  if (zooms(event)) {
    zoomAt(event);
    return;
  }
  if (ignores(event)) {
    return;
  }
  // While the laser pointer is on, a click moves the dot only. While the
  // drawing is on, a click draws.
  if (pointing(state) || drawing(state)) {
    return;
  }
  handle(
    {
      kind: "click",
      region: side(event.clientX, window.innerWidth),
      element: element(event),
    },
    event,
  );
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
    // While the laser pointer is on, a movement of a finger moves the dot.
    // While the drawing is on, it draws a line. While the zoom is on, only a
    // tap has an effect.
    if (
      start === null ||
      finger === undefined ||
      pointing(state) ||
      drawing(state) ||
      zooming(state)
    ) {
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
  show(fromHash(program, state, location.hash, deck));
});

// Tell if a window is a window that this window opened. The speaker view has
// this window as its `opener`. A frame of the document, such as the page of an
// embed, has no opener, so it cannot become the partner of the present view.
function opened(source: Window | null): boolean {
  try {
    return source !== null && source.opener === window;
  } catch {
    return false;
  }
}

// A message from the other window. A message from each other window has no
// effect. After a reload, the present view has no partner, and the next
// message of the speaker view makes the connection again. The present view
// answers a request of the speaker view with its full state and its own time.
window.addEventListener("message", (event: MessageEvent) => {
  const source = event.source as Window | null;
  if (partner === null && !isSpeaker && opened(source)) {
    partner = source;
  }
  if (partner === null || source !== partner) {
    return;
  }
  if (isRequest(event.data)) {
    if (!isSpeaker) {
      partner.postMessage(message(program, state, deck, time, scheme()), "*");
      // A speaker view that loads after a line also gets the drawing, and
      // one that loads after a zoom gets the zoom.
      if (shownLines().length > 0) {
        partner.postMessage(drawingMessage(shownLines()), "*");
      }
      if (zoomed !== null) {
        partner.postMessage(zoomMessage(zoomed), "*");
      }
    }
    return;
  }
  // The place of the laser pointer of the other window. The message holds no
  // state, so it has no time.
  if (isPointer(event.data)) {
    point(placeOf(event.data));
    return;
  }
  // The drawing of the other window. It replaces the drawing of this window,
  // and an empty list removes it.
  if (isDrawing(event.data)) {
    lines = event.data.lines;
    stroke = null;
    showDrawing(lines, state.view);
    return;
  }
  // The zoom of the other window. Null shows the full slide.
  if (isZoom(event.data)) {
    zoomTo(event.data.area, false);
    return;
  }
  if (!isMessage(event.data)) {
    return;
  }
  const incoming = limit(event.data.time, Date.now());
  if (!accepts(time, incoming, isSpeaker)) {
    return;
  }
  time = incoming;
  showScheme(event.data.scheme);
  show(follow(program, state, event.data, deck), false);
});
