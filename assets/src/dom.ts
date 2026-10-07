// The code that reads the document and writes to it.
//
// `interpreter.ts` does not touch the document, and this module does not
// decide the next state. `main.ts` connects the two.

import { parse } from "./deck.ts";
import type { Deck } from "./deck.ts";
import { helpMode } from "./interpreter.ts";
import type { Transition } from "./interpreter.ts";
import { parse as parseProgram } from "./program.ts";
import type { Program, Projections } from "./program.ts";
import { fromAddress } from "./scheme.ts";
import type { Scheme } from "./scheme.ts";
import { position } from "./speaker.ts";
import type { Pace } from "./speaker.ts";
import { current } from "./state.ts";
import type { State } from "./state.ts";

// Read the list of the steps from the element `expresso-deck`, where the
// renderer writes it as JSON. A document with no list is a defect of the
// renderer, so an error here is correct.
export function deck(): Deck {
  const element = document.getElementById("expresso-deck");
  if (element === null) {
    throw new Error("The document has no list of the steps");
  }
  return parse(element.textContent ?? "");
}

// Read the program of the presenter from the element `expresso-program`, where
// the renderer writes it as JSON. A document with no program is a defect of the
// renderer, so an error here is correct.
export function program(): Program {
  const element = document.getElementById("expresso-program");
  if (element === null) {
    throw new Error("The document has no program of the presenter");
  }
  return parseProgram(element.textContent ?? "");
}

// Run a change of the document as a transition, or run it at once. The
// browser needs the View Transitions API, and the reader must not ask for
// reduced motion. The kind and the direction go on the `html` element, and
// the style sheet gives each kind its animation.
export function animate(change: Transition | null, update: () => void): void {
  const reduced = window.matchMedia?.(
    "(prefers-reduced-motion: reduce)",
  ).matches;
  if (
    change === null ||
    reduced === true ||
    typeof document.startViewTransition !== "function"
  ) {
    update();
    return;
  }
  document.documentElement.dataset.transition = change.kind;
  document.documentElement.dataset.direction = change.direction;
  document.startViewTransition(update);
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

// Apply a state to the document. The function applies the projections of the
// program, and `Expresso.Presenter.Projection` tells what each projection
// does. It shows the slide of the current step at that step, and it hides each
// other slide. The generated style block reads `data-step`, and
// docs/overlays.md gives the CSS contract. A deck with no slide gets the
// projections only. The list of keys shows the rows of the mode under it, and
// the speaker view writes the texts of its elements.
export function apply(state: State, deck: Deck, program: Program): void {
  project(program.project, state, deck);
  if (state.help) {
    help(helpMode(program, state));
  }
  for (let number = 1; number <= deck.slides.length; number++) {
    slide(number).style.display = "none";
  }
  // A deck can hold no slide. The view still changes, and the function must
  // not read a slide that the document does not have.
  const entry = current(state, deck);
  if (entry === undefined) {
    return;
  }
  const shown = slide(entry.slide);
  shown.dataset.step = String(entry.step);
  shown.style.display = "flex";
  if (state.view === "speaker") {
    speaker(state, deck);
  }
}

// Write each projection of the program. A mark goes on each element of its
// selector whose number agrees with the first of its values, and each other
// element of the selector loses the attribute.
function project(rules: Projections, state: State, deck: Deck): void {
  const body = document.body;
  for (const { field, name, flag } of rules.attributes) {
    const value = state[field];
    if (!flag) {
      body.setAttribute(name, String(value));
    } else if (value === true) {
      body.setAttribute(name, "true");
    } else {
      body.removeAttribute(name);
    }
  }
  const entry = current(state, deck);
  for (const { name, entry: key } of rules.properties) {
    body.style.setProperty(name, String(entry?.[key] ?? 0));
  }
  for (const { attribute, selector, key, values } of rules.marks) {
    for (const element of document.querySelectorAll(selector)) {
      const number = Number(element.getAttribute(`data-${key}`));
      const found = values.find(
        ([, field, offset]) => Number(state[field]) + offset === number,
      );
      if (found === undefined) {
        element.removeAttribute(attribute);
      } else {
        element.setAttribute(attribute, found[0]);
      }
    }
  }
}

// The notes of the page of the current step go into the element
// `speaker-notes`, and the position goes into the element `speaker-position`.
// The renderer writes the index of each step on its page in `data-index`.
function speaker(state: State, deck: Deck): void {
  const page = pages().find(
    (each) => Number(each.dataset.index) === state.index,
  );
  text("speaker-notes", page?.querySelector(".notes")?.textContent ?? "");
  text("speaker-position", position(current(state, deck), state.blank));
}

// Show the list of keys of one mode. The renderer writes the element `help`
// with one list for each mode, and each list has the name of its mode in
// `data-mode`. The style sheet shows the element while the `body` has
// `data-help`.
function help(name: string | undefined): void {
  const lists = document.getElementById("help")?.children ?? [];
  for (const list of Array.from(lists) as HTMLElement[]) {
    list.hidden = list.dataset.mode !== name;
  }
}

// Write the time left and the pace into the element `speaker-left`. The style
// sheet gives the pace its color. A talk with no length gets no text, and the
// style sheet then hides the element.
export function timeLeft(value: string, current: Pace | null): void {
  const element = document.getElementById("speaker-left");
  if (element === null) {
    return;
  }
  element.textContent = value;
  if (current === null) {
    delete element.dataset.pace;
  } else {
    element.dataset.pace = current;
  }
}

// The variant that the key `t` chose for this document, or null for the
// variant of the screen. `scheme.ts` gives the rules.
export function scheme(): Scheme {
  return fromAddress(document.documentElement.dataset.scheme ?? null);
}

// Show a variant of the theme, or the variant of the screen for null. A
// document with one variant has no `data-variants`, and it keeps its theme.
export function showScheme(value: Scheme): void {
  const root = document.documentElement;
  if (!root.hasAttribute("data-variants")) {
    return;
  }
  if (value === null) {
    delete root.dataset.scheme;
  } else {
    root.dataset.scheme = value;
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
  return Array.from(document.querySelectorAll<HTMLElement>(".handout-page"));
}
