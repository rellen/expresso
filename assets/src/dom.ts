// The code that reads the document and writes to it.
//
// `state.ts` does not touch the document, and this module does not decide the
// next state. `main.ts` connects the two.

import { rows } from "./help.ts";
import { describe } from "./speaker.ts";
import { columns, fraction, maxStep, mode, upcoming } from "./state.ts";
import type { Limits, State } from "./state.ts";

// The renderer writes `data-progress="false"` on the `body` for a deck that
// hides the progress bar at the start. The key `g` can still show it.
export function showsProgress(): boolean {
  return document.body.dataset.progress !== "false";
}

// The renderer gives each slide a `section` with the class `slide`, the
// identifier `slide-<number>` and the attribute `data-max-step`. The first
// slide is slide 1.
export function limits(): Limits {
  const count = document.getElementsByClassName("slide").length;
  const steps: number[] = [];
  for (let number = 1; number <= count; number++) {
    steps.push(Number(slide(number).dataset.maxStep) || 1);
  }
  return { slides: count, steps };
}

// Read a slide by its number. A missing slide is a defect of the renderer, so
// an error here is correct.
function slide(number: number): HTMLElement {
  const element = document.getElementById(`slide-${number}`);
  if (element === null) {
    throw new Error(`The document has no slide ${number}`);
  }
  return element;
}

// Apply a state to the document. The function writes the view on the `body`,
// it shows the slide of the state at the step of the state, and it hides each
// other slide. A deck with no slide gets the view only. The style sheet reads
// `data-view` and `data-blank`, and the generated style block reads
// `data-step`. docs/overlays.md gives the CSS contract. The speaker view also
// writes `data-speaker` on two pages, and the texts of its three elements.
// The overview writes `data-overview` on the `body`, and attributes on pages.
export function apply(state: State, limits: Limits): void {
  document.body.dataset.view = state.view;
  if (state.blank) {
    document.body.dataset.blank = "true";
  } else {
    delete document.body.dataset.blank;
  }
  document.body.dataset.progress = String(state.progress);
  document.body.dataset.every = String(state.every);
  const bar = document.getElementById("progress");
  if (bar !== null) {
    bar.style.width = `${fraction(state, limits) * 100}%`;
  }
  if (state.overview) {
    document.body.dataset.overview = "true";
    overview(state, limits);
  } else {
    delete document.body.dataset.overview;
  }
  if (state.help) {
    document.body.dataset.help = "true";
    help(state);
  } else {
    delete document.body.dataset.help;
  }
  for (let number = 1; number <= limits.slides; number++) {
    slide(number).style.display = "none";
  }
  // A deck can hold no slide. The view still changes, and the function must
  // not read a slide that the document does not have.
  if (limits.slides === 0) {
    return;
  }
  const current = slide(state.slide);
  current.dataset.step = String(state.step);
  current.style.display = "flex";
  if (state.view === "speaker") {
    speaker(state, limits);
  }
}

// The speaker view shows two pages of the handout view. The page of the
// current step gets `data-speaker="current"`, and the page of the next step
// gets `data-speaker="next"`. The style sheet places the two pages. The notes
// of the current page go into the element `speaker-notes`, and the position
// goes into the element `speaker-position`.
function speaker(state: State, limits: Limits): void {
  const after = upcoming(state, limits);
  let notes = "";
  for (const page of pages()) {
    const slide = Number(page.dataset.slide);
    const step = Number(page.dataset.step);
    if (slide === state.slide && step === state.step) {
      page.dataset.speaker = "current";
      notes = page.querySelector(".notes")?.textContent ?? "";
    } else if (after !== null && slide === after.slide && step === after.step) {
      page.dataset.speaker = "next";
    } else {
      delete page.dataset.speaker;
    }
  }
  text("speaker-notes", notes);
  text("speaker-position", describe(state, limits));
}

// The overview shows the page of the last step of each slide in a grid. The
// page of each last step gets `data-thumbnail`, and the page of the selected
// slide also gets `data-selected`. Each page is as large as the window, and
// the style sheet scales it with `zoom`. The padding and the gaps of the grid
// are 1vw wide and 1vh high. The number of rows is not more than the number of
// columns, so a zoom that fits the width also fits the height.
function overview(state: State, limits: Limits): void {
  const width = columns(limits.slides);
  const style = document.body.style;
  style.setProperty("--overview-columns", String(width));
  style.setProperty(
    "--overview-zoom",
    String((98 - (width - 1)) / (100 * width)),
  );
  for (const page of pages()) {
    const slide = Number(page.dataset.slide);
    if (Number(page.dataset.step) === maxStep(slide, limits)) {
      page.dataset.thumbnail = "";
    } else {
      delete page.dataset.thumbnail;
    }
    if (slide === state.selected && page.dataset.thumbnail !== undefined) {
      page.dataset.selected = "";
    } else {
      delete page.dataset.selected;
    }
  }
}

// Make the elements of the speaker view that the renderer does not write. The
// elements go into the handout view, because the style sheet places them in
// the grid of that view. A second call makes no new element.
export function speakerPanel(): void {
  if (document.getElementById("speaker-notes") !== null) {
    return;
  }
  const handout = document.getElementsByClassName("handout")[0];
  for (const id of ["speaker-notes", "speaker-position", "speaker-timer"]) {
    const element = document.createElement("div");
    element.id = id;
    handout?.appendChild(element);
  }
}

// Write the list of keys of the view of the state into the element `help`.
// The function makes the element at the first call. Each row holds the names
// of the keys and their function, as text and not as HTML. The style sheet
// shows the element while the `body` has `data-help`.
function help(state: State): void {
  let panel = document.getElementById("help");
  if (panel === null) {
    panel = document.createElement("div");
    panel.id = "help";
    document.body.appendChild(panel);
  }
  panel.replaceChildren();
  for (const [keys, text] of rows(mode(state))) {
    const row = document.createElement("div");
    const name = document.createElement("kbd");
    name.textContent = keys;
    const function_ = document.createElement("span");
    function_.textContent = text;
    row.appendChild(name);
    row.appendChild(function_);
    panel.appendChild(row);
  }
}

// Write a text into an element of the speaker view. The text is not HTML.
export function text(id: string, value: string): void {
  const element = document.getElementById(id);
  if (element !== null) {
    element.textContent = value;
  }
}

// The pages of the handout view. The renderer gives each page the class
// `handout-page` and the attributes `data-slide` and `data-step`.
function pages(): HTMLElement[] {
  return Array.from(
    document.getElementsByClassName("handout-page"),
  ) as HTMLElement[];
}
