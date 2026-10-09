// The layout check of `?check` in the address.
//
// The check shows each step of the deck in the present view, one after the
// other, and it measures the elements of the slide. It finds two kinds of
// problem:
//
// - `outside`: an element goes past an edge of the window, so a part of it
//   does not show. The check measures what the element shows: its text and
//   its content, and not its box. A text box is as wide as the slide, so its
//   box goes past an edge when it moves, while its text stays in the window.
// - `wrap`: a line of a code element is too long for its box, so the browser
//   breaks it into two or more lines on the slide.
//
// The size of the window changes the layout, so the report gives the size.
// The check sets the time of each animation to zero, and it then reads the
// final place of each element at each step.
//
// The functions that calculate take numbers and return numbers, so the tests
// run them without a document. `audit` and `report` read and write the
// document.

// A rectangle in the coordinates of the window.
export type Box = Readonly<{
  left: number;
  top: number;
  right: number;
  bottom: number;
}>;

export type Edge = "left" | "top" | "right" | "bottom";

// One problem of the layout. `amount` is the distance past the edge in
// pixels for `outside`, and the number of broken lines for `wrap`. `step` is
// the first step that has the problem.
export type Problem = Readonly<{
  slide: number;
  step: number;
  kind: "outside" | "wrap";
  edge: Edge | null;
  amount: number;
  element: string;
}>;

// A distance of one pixel or less comes from the rounding of the browser.
const TOLERANCE = 1;

// A line of code that is more than this number of times its line height is a
// broken line. A line with no break is one line height.
const BROKEN = 1.5;

// The smallest box that holds each box. No box returns null.
export function union(boxes: readonly Box[]): Box | null {
  if (boxes.length === 0) {
    return null;
  }
  return {
    left: Math.min(...boxes.map((box) => box.left)),
    top: Math.min(...boxes.map((box) => box.top)),
    right: Math.max(...boxes.map((box) => box.right)),
    bottom: Math.max(...boxes.map((box) => box.bottom)),
  };
}

// The edge that a box goes past by the largest distance, with that distance.
// A box inside the area returns null.
export function past(
  box: Box,
  area: Box,
): { edge: Edge; amount: number } | null {
  const distances: [Edge, number][] = [
    ["left", area.left - box.left],
    ["top", area.top - box.top],
    ["right", box.right - area.right],
    ["bottom", box.bottom - area.bottom],
  ];
  let found: { edge: Edge; amount: number } | null = null;
  for (const [edge, amount] of distances) {
    if (amount > TOLERANCE && (found === null || amount > found.amount)) {
      found = { edge, amount: Math.round(amount) };
    }
  }
  return found;
}

// The number of lines that the browser broke, from the height of each line
// of a code element and the line height of the element.
export function broken(heights: readonly number[], lineHeight: number): number {
  if (!(lineHeight > 0)) {
    return 0;
  }
  return heights.filter((height) => height > lineHeight * BROKEN).length;
}

// The text that names an element in the report: its kind and the start of
// its text. A text of more than 40 characters ends with "…".
export function label(kind: string, text: string): string {
  const words = text.replace(/\s+/g, " ").trim();
  const start = words.length > 40 ? `${words.slice(0, 40)}…` : words;
  return start === "" ? kind : `${kind} “${start}”`;
}

// The sentence of the report for one problem.
export function sentence(problem: Problem): string {
  const where = `Slide ${problem.slide}, step ${problem.step}`;
  if (problem.kind === "wrap") {
    const lines =
      problem.amount === 1 ? "1 line breaks" : `${problem.amount} lines break`;
    return `${where}: ${lines} in the ${problem.element}`;
  }
  return `${where}: the ${problem.element} goes ${problem.amount} px past the ${problem.edge} edge`;
}

// The elements of a slide. A part of a diagram is not one of them, because a
// part can move past the box of its diagram.
const ELEMENTS =
  ".slide-heading-container, .text-box, .text-area, .image, .list, .table, .quotation, .code, .math, .diagram, .embed, .columns, .column, .shape";

// The content of an element: the tags that show their box. The content can
// be wider than the box of its element, so the check also measures each one.
// The `svg` of a line or an arrow covers the whole slide, so the check
// measures its `line`, and not the `svg`.
const CONTENT =
  "math, img, svg:not(.shape-line), pre, iframe, table, .shape-line line";

const MEASURED = `${ELEMENTS}, ${CONTENT}`;

// The kind of an element for the report, from its first class.
function kind(element: Element): string {
  if (element.classList.contains("slide-heading-container")) {
    return "heading";
  }
  return (element.classList[0] ?? element.tagName.toLowerCase()).replace(
    "-",
    " ",
  );
}

// The name of an element for the report. The content of an element takes the
// name of its element. An image gives its alt text, and a diagram gives the
// title of its SVG.
function name(measured: Element): string {
  const element = measured.closest(ELEMENTS) ?? measured;
  const image = element.querySelector("img");
  if (image !== null) {
    return label(kind(element), image.alt);
  }
  const title = element.querySelector("svg > title");
  if (title !== null) {
    return label(kind(element), title.textContent ?? "");
  }
  return label(kind(element), element.textContent ?? "");
}

function shown(element: Element): boolean {
  const style = getComputedStyle(element);
  return style.visibility !== "hidden" && style.display !== "none";
}

// The box of what an element shows. A tag of the content shows its box. Each
// other element shows its text and its content, so its box is the union of
// the boxes of each text and each tag of its content that show. An element
// that shows nothing returns null.
function extent(element: Element): Box | null {
  if (element.matches(CONTENT)) {
    return element.getBoundingClientRect();
  }
  const boxes: Box[] = [];
  const range = document.createRange();
  const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
  for (let node = walker.nextNode(); node !== null; node = walker.nextNode()) {
    const parent = node.parentElement;
    if (
      (node.textContent ?? "").trim() !== "" &&
      parent !== null &&
      shown(parent)
    ) {
      range.selectNodeContents(node);
      boxes.push(range.getBoundingClientRect());
    }
  }
  for (const content of Array.from(element.querySelectorAll(CONTENT))) {
    if (shown(content)) {
      boxes.push(content.getBoundingClientRect());
    }
  }
  return union(
    boxes.filter((box) => box.right > box.left || box.bottom > box.top),
  );
}

// The problems of the slide that shows now. An element that goes past an edge
// counts only when no element inside it goes past the same edge, so the
// report names the innermost element. The height of a line comes from
// `offsetHeight`, which does not change when an `on` entity turns the code.
function measure(slide: HTMLElement, number: number, step: number): Problem[] {
  const area: Box = {
    left: 0,
    top: 0,
    right: window.innerWidth,
    bottom: window.innerHeight,
  };
  const elements = Array.from(slide.querySelectorAll(MEASURED)).filter(shown);
  const outside = new Map<Element, { edge: Edge; amount: number }>();
  for (const element of elements) {
    const box = extent(element);
    const found = box === null ? null : past(box, area);
    if (found !== null) {
      outside.set(element, found);
    }
  }
  const problems: Problem[] = [];
  for (const [element, { edge, amount }] of outside) {
    const inner = Array.from(outside).some(
      ([other, found]) =>
        other !== element && element.contains(other) && found.edge === edge,
    );
    if (!inner) {
      const problem = { kind: "outside", edge, amount } as const;
      problems.push({
        slide: number,
        step,
        ...problem,
        element: name(element),
      });
    }
  }
  for (const code of elements.filter((each) => each.matches(".code"))) {
    const pre = code.querySelector("pre");
    const lineHeight =
      pre === null ? 0 : parseFloat(getComputedStyle(pre).lineHeight);
    const heights = Array.from(code.querySelectorAll(".line"))
      .filter(shown)
      .map((line) => (line as HTMLElement).offsetHeight);
    const amount = broken(heights, lineHeight);
    if (amount > 0) {
      problems.push({
        slide: number,
        step,
        kind: "wrap",
        edge: null,
        amount,
        element: name(code),
      });
    }
  }
  return problems;
}

// Keep the first step of each problem. Two problems are the same problem when
// they have the slide, the kind, the edge and the element.
export function first(problems: readonly Problem[]): Problem[] {
  const kept = new Map<string, Problem>();
  for (const problem of problems) {
    const key = [
      problem.slide,
      problem.kind,
      problem.edge,
      problem.element,
    ].join("|");
    if (!kept.has(key)) {
      kept.set(key, problem);
    }
  }
  return Array.from(kept.values());
}

// Show each step with `show`, and measure the slide of the step. `steps`
// gives the slide and the step of each index. The animations take no time
// during the check, and they take their own time again after it.
export function audit(
  steps: readonly { slide: number; step: number }[],
  show: (index: number) => void,
): Problem[] {
  const root = document.documentElement.style;
  root.setProperty("--dur", "0s");
  root.setProperty("--motion", "0");
  const problems: Problem[] = [];
  try {
    steps.forEach(({ slide, step }, index) => {
      show(index);
      const element = document.getElementById(`slide-${slide}`);
      if (element !== null) {
        problems.push(...measure(element, slide, step));
      }
    });
  } finally {
    root.removeProperty("--dur");
    root.removeProperty("--motion");
  }
  return first(problems);
}

// Write the report into the document, and each problem to the console. The
// report is an element `layout-check` with a link to the step of each problem.
// `data-layout` on the `body` holds `ok` or `problems`, so a test can read the
// result.
export function report(problems: readonly Problem[]): void {
  const size = `${window.innerWidth} × ${window.innerHeight}`;
  const panel = document.createElement("aside");
  panel.id = "layout-check";
  panel.setAttribute("aria-label", "Layout check");
  const heading = document.createElement("p");
  heading.textContent =
    problems.length === 0
      ? `Layout check at ${size}: no problems`
      : `Layout check at ${size}: ${problems.length} ${problems.length === 1 ? "problem" : "problems"}`;
  panel.append(heading);
  const list = document.createElement("ol");
  for (const problem of problems) {
    const item = document.createElement("li");
    const link = document.createElement("a");
    link.href = `#${problem.slide}.${problem.step}`;
    link.textContent = sentence(problem);
    item.append(link);
    list.append(item);
    console.warn(`Expresso layout check: ${sentence(problem)}`);
  }
  panel.append(list);
  const close = document.createElement("button");
  close.type = "button";
  close.textContent = "Close";
  close.addEventListener("click", () => panel.remove());
  panel.append(close);
  document.body.append(panel);
  document.body.dataset.layout = problems.length === 0 ? "ok" : "problems";
}
