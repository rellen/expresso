// The morph between two slides. An element of one slide and an element of the
// other slide that are the same element get the same `view-transition-name`,
// so the view transition of the slide change moves the element from its old
// place and size to its new place and size. The rest of the slide fades.
//
// Two elements are the same element when:
//
// - they have the same `morph` key, which the renderer writes as
//   `data-morph-key`, whatever their kinds; or
// - with the morph `auto`, they have the same kind and the same content, and
//   no other element of either slide has that kind and that content. The
//   heading of a slide is an element of the kind `heading`.
//
// An element inside an element that already has a partner gets no partner of
// its own, because it moves with its parent. Two code elements that are the
// same element also pair each token that the two codes share, in order, so a
// token moves inside the code.
//
// The slide with the higher number gives the mode, as it gives the kind of a
// transition: `auto`, `named` (keys only) or `off`.

import { ELEMENT_KINDS } from "./schema.ts";
import type { MorphContent } from "./schema.ts";

export type Mode = "auto" | "named" | "off";

// A pair of elements, with the name of their view transition.
export type Pair = Readonly<{ name: string; from: Element; to: Element }>;

// A kind of element that the morph uses: its class, its name and the content
// that the auto morph compares.
type Kind = readonly [string, string, MorphContent];

// The kinds of element that the morph uses, in the order of their check.
// `Expresso.Element.kinds/0` gives them.
const KINDS = ELEMENT_KINDS.filter((kind): kind is Kind => kind[2] !== null);

const SELECTOR = [
  ...KINDS.map(([name]) => `.${name}`),
  "[data-morph-key]",
].join(", ");

// The most tokens of a code that the morph pairs. A longer code moves as one
// element, because each pair is a view transition of its own.
export const MAX_TOKENS = 400;

function find(element: Element): Kind | null {
  return KINDS.find(([name]) => element.classList.contains(name)) ?? null;
}

// The kind of an element, or null for an element that the morph does not use.
export function kindOf(element: Element): string | null {
  return find(element)?.[1] ?? null;
}

function text(element: Element | null): string {
  return (element?.textContent ?? "").replace(/\s+/g, " ").trim();
}

// The content of an element for the auto morph. An image and a page compare
// their source, a video and a sound the number of their file, an icon and a
// QR code their drawing, a code element its language, and a stat its label.
// Each other kind compares its text.
export function content(element: Element, compared: MorphContent): string {
  switch (compared) {
    case "source":
      return (
        element.querySelector("img, iframe")?.getAttribute("src") ??
        text(element)
      );
    case "file": {
      const media = element.querySelector("[data-video], [data-audio]");
      return (
        media?.getAttribute("data-video") ??
        media?.getAttribute("data-audio") ??
        text(element)
      );
    }
    case "drawing":
      return element.querySelector("svg")?.innerHTML ?? "";
    case "language":
      return (
        element.getAttribute("data-language") ??
        element.querySelector("code")?.className ??
        ""
      );
    case "label":
      return text(element.querySelector(".stat-label"));
    case "text":
      return text(element);
  }
}

// The elements of a slide that the morph can use, in document order. The
// slides of the fake document of the tests have no query, and give none.
function elements(slide: Element): Element[] {
  return typeof slide.querySelectorAll === "function"
    ? Array.from(slide.querySelectorAll(SELECTOR))
    : [];
}

// The elements of each value, from a list of elements and a function that
// gives the value of each one, or null for no value.
function group(
  list: readonly Element[],
  value: (element: Element) => string | null,
): Map<string, Element[]> {
  const groups = new Map<string, Element[]>();
  for (const element of list) {
    const key = value(element);
    if (key !== null) {
      groups.set(key, [...(groups.get(key) ?? []), element]);
    }
  }
  return groups;
}

// The pairs of two lists of values by their longest common subsequence: the
// index in the first list and the index in the second list of each pair, in
// order.
export function common(
  first: readonly string[],
  second: readonly string[],
): [number, number][] {
  const rows = first.length;
  const columns = second.length;
  const lengths: number[][] = Array.from({ length: rows + 1 }, () =>
    Array.from({ length: columns + 1 }, () => 0),
  );
  for (let i = rows - 1; i >= 0; i--) {
    for (let j = columns - 1; j >= 0; j--) {
      lengths[i]![j] =
        first[i] === second[j]
          ? lengths[i + 1]![j + 1]! + 1
          : Math.max(lengths[i + 1]![j]!, lengths[i]![j + 1]!);
    }
  }
  const pairs: [number, number][] = [];
  let i = 0;
  let j = 0;
  while (i < rows && j < columns) {
    if (first[i] === second[j]) {
      pairs.push([i, j]);
      i++;
      j++;
    } else if (lengths[i + 1]![j]! >= lengths[i]![j + 1]!) {
      i++;
    } else {
      j++;
    }
  }
  return pairs;
}

// The tokens of a code element: the innermost spans of its code with a text,
// in order. A line number is not a token.
function tokens(code: Element): Element[] {
  return Array.from(code.querySelectorAll("pre span")).filter(
    (span) =>
      span.querySelector("span") === null &&
      !span.classList.contains("line-number") &&
      span.closest(".line-number") === null &&
      text(span) !== "",
  );
}

// The pairs of two slides, with their names.
export function pairs(from: Element, to: Element, mode: Mode): Pair[] {
  if (mode === "off") {
    return [];
  }
  const found: [Element, Element][] = [];
  const paired = (element: Element, side: 0 | 1): boolean =>
    found.some(
      (pair) => pair[side] !== element && pair[side].contains(element),
    );

  const key = (element: Element): string | null =>
    element.getAttribute("data-morph-key");
  const before = elements(from);
  const after = elements(to);
  const keyed = [group(before, key), group(after, key)] as const;
  for (const [name, olds] of keyed[0]) {
    const news = keyed[1].get(name);
    if (olds.length === 1 && news?.length === 1) {
      found.push([olds[0]!, news[0]!]);
    }
  }

  if (mode === "auto") {
    const signature = (element: Element): string | null => {
      const kind = find(element);
      return key(element) === null && kind !== null
        ? `${kind[1]}\u0000${content(element, kind[2])}`
        : null;
    };
    const signed = [group(before, signature), group(after, signature)] as const;
    for (const element of before) {
      const name = signature(element);
      const news = name === null ? undefined : signed[1].get(name);
      if (
        name !== null &&
        signed[0].get(name)?.length === 1 &&
        news?.length === 1 &&
        !paired(element, 0) &&
        !paired(news[0]!, 1)
      ) {
        found.push([element, news[0]!]);
      }
    }
  }

  // The loop adds the tokens to `found`, so it reads a copy of the elements.
  for (const [old, current] of found.slice()) {
    if (kindOf(old) === "code" && kindOf(current) === "code") {
      const first = tokens(old);
      const second = tokens(current);
      if (first.length <= MAX_TOKENS && second.length <= MAX_TOKENS) {
        for (const [i, j] of common(first.map(text), second.map(text))) {
          found.push([first[i]!, second[j]!]);
        }
      }
    }
  }

  return found.map(([old, current], index) => ({
    name: `expresso-morph-${index + 1}`,
    from: old,
    to: current,
  }));
}

// The mode of the change between two slides: the mode of the slide with the
// higher number.
export function modeOf(
  from: Element,
  to: Element,
  fromNumber: number,
  toNumber: number,
): Mode {
  const value = (toNumber > fromNumber ? to : from).getAttribute("data-morph");
  return value === "named" || value === "off" ? value : "auto";
}

// Tell if an element shows: it has a box, and it is not hidden or transparent.
export function visible(element: Element): boolean {
  const check = (
    element as Element & { checkVisibility?: (options: object) => boolean }
  ).checkVisibility;
  return check === undefined
    ? true
    : check.call(element, { opacityProperty: true, visibilityProperty: true });
}
