// The moves of the parts of a formula. An `on` entity of a part of a math
// element can take `move_to`, the name of a different part of the same
// formula. The place of a part comes from the fonts of the browser, so
// `Expresso.Element.Math.place/1` cannot measure it. That function writes the
// move as `--x: var(--to-x-name)` and `--y: var(--to-y-name)`, and it gives the
// part the attribute `data-move-to` with the name of each part that it moves
// to. This module measures each distance and sets the two custom properties on
// each element of the part.
//
// The module measures a copy of the formula with the class `math-measure`. The
// style sheet hides the copy and stops each transform and each transition in
// it, so the copy shows each part at its place, and a move that plays does not
// change the result. The copy goes after the formula, so it has the same font
// and the same width, and the module removes it at once.
//
// A distance is in the coordinates of the formula: the module divides the
// distance on the screen by the scale of the slide. A formula that does not
// show has no size, so the module measures it when it shows. A change of the
// size of the window, or a font that loads, measures each formula again.

import { union } from "./layout.ts";
import type { Box } from "./layout.ts";

// The distance from the center of one part to the center of a different part.
export type Move = Readonly<{ x: number; y: number }>;

// The distance from the center of `from` to the center of `to`, divided by
// `scale`, with two decimals.
export function distance(from: Box, to: Box, scale: number): Move {
  const round = (value: number): number => Math.round(value * 100) / 100 || 0;
  return {
    x: round((to.left + to.right - from.left - from.right) / 2 / scale),
    y: round((to.top + to.bottom - from.top - from.bottom) / 2 / scale),
  };
}

// The names that an element of a formula has: its attribute `data-part`, from
// `\part` or `\id`, and each of its classes, from `\class`.
export function names(element: {
  getAttribute(name: string): string | null;
}): string[] {
  const part = element.getAttribute("data-part");
  const classes = (element.getAttribute("class") ?? "").split(/\s+/);
  return [...(part === null ? [] : [part]), ...classes].filter(
    (name) => name !== "",
  );
}

// The size of the window and the number of loaded fonts at each measure of a
// formula. A formula with the current key needs no new measure.
const measured = new WeakMap<Element, string>();
let fonts = 0;

// Measure the moves of each formula that shows and that has a part with
// `move_to`.
export function place(): void {
  const key = `${window.innerWidth}x${window.innerHeight}:${fonts}`;
  const formulas = new Set<HTMLElement>();
  for (const part of document.querySelectorAll("[data-move-to]")) {
    const math = part.closest<HTMLElement>(".math");
    if (math !== null && !math.classList.contains("math-measure")) {
      formulas.add(math);
    }
  }
  for (const math of formulas) {
    if (measured.get(math) !== key && math.getClientRects().length > 0) {
      measure(math);
      measured.set(math, key);
    }
  }
}

// Measure each formula again at the next `place`, because a font loaded.
export function forget(): void {
  fonts += 1;
}

function measure(math: HTMLElement): void {
  const copy = math.cloneNode(true) as HTMLElement;
  copy.classList.add("math-measure");
  copy.setAttribute("aria-hidden", "true");
  copy.style.width = `${math.offsetWidth}px`;
  math.after(copy);
  try {
    const scale = copy.getBoundingClientRect().width / copy.offsetWidth;
    if (scale > 0) {
      write(math, copy, scale);
    }
  } finally {
    copy.remove();
  }
}

// Set the custom properties of each part with `move_to`. The elements of one
// part have the same `data-el`, so the part moves as one: from the center of
// the box of all its elements to the center of the box of all the elements
// of the other part.
function write(math: HTMLElement, copy: HTMLElement, scale: number): void {
  const elements = Array.from(copy.querySelectorAll("*"));
  const box = (selected: Element[]): Box | null =>
    union(selected.map((element) => element.getBoundingClientRect()));
  const parts = new Map<string, Element[]>();
  for (const element of copy.querySelectorAll("[data-move-to]")) {
    const el = element.getAttribute("data-el") ?? "";
    parts.set(el, [...(parts.get(el) ?? []), element]);
  }
  for (const [el, part] of parts) {
    const from = box(part);
    const targets = (part[0]?.getAttribute("data-move-to") ?? "").split(" ");
    const originals = Array.from(
      math.querySelectorAll<HTMLElement | SVGElement>(
        `[data-el="${CSS.escape(el)}"]`,
      ),
    );
    for (const target of targets.filter((name) => name !== "")) {
      const to = box(elements.filter((each) => names(each).includes(target)));
      if (from === null || to === null) {
        continue;
      }
      const { x, y } = distance(from, to, scale);
      for (const original of originals) {
        original.style.setProperty(`--to-x-${target}`, `${x}px`);
        original.style.setProperty(`--to-y-${target}`, `${y}px`);
      }
    }
  }
}
