// The accessibility check of `?check=a11y`, and the result of each check for
// `mix expresso --check`.
//
// `Expresso.Check` puts axe-core into a copy of the document, and a headless
// browser opens the copy with `?check` or `?check=a11y`. The layout check of
// `layout.ts` runs first. With `?check=a11y`, axe-core then reads the document
// at each step of each slide and in each view. The page writes the result of
// the two checks as JSON into an element `check-result`, and the browser
// writes the document to its standard output.

// A violation of a rule of axe-core. `where` names the step or the view,
// `rule` is the id of the rule, `help` is its short description, and
// `targets` holds a CSS selector for each element that fails.
export type Finding = Readonly<{
  where: string;
  rule: string;
  help: string;
  targets: readonly string[];
}>;

// The part of the API of axe-core that the check uses.
export type Axe = Readonly<{
  run(
    context: Document | Element,
    options: object,
  ): Promise<{
    violations: readonly {
      id: string;
      help: string;
      nodes: readonly { target: readonly unknown[] }[];
    }[];
  }>;
}>;

// The result for the command: the size of the window, a sentence for each
// problem of the layout, and each violation of axe-core. `accessibility` is
// null when the page did not run axe-core.
export type Result = Readonly<{
  width: number;
  height: number;
  layout: readonly string[];
  accessibility: readonly Finding[] | null;
}>;

// The axe-core of the page, or undefined for a page without it.
export function engine(): Axe | undefined {
  const value = (window as { axe?: Axe }).axe;
  return typeof value?.run === "function" ? value : undefined;
}

// Only the violations: the other kinds of result take time and the check
// does not read them.
const OPTIONS = { resultTypes: ["violations"] };

// Keep the first finding of each rule on each element. A dimmed line that
// fails at each step of its slide then gives one finding.
export function first(findings: readonly Finding[]): Finding[] {
  const kept = new Map<string, Finding>();
  for (const finding of findings) {
    const key = `${finding.rule} ${finding.targets.join(", ")}`;
    if (!kept.has(key)) {
      kept.set(key, finding);
    }
  }
  return Array.from(kept.values());
}

// Show each step with `show`, and run axe-core on its slide. Then show each
// view, and run axe-core on the document. `views` gives the name of each view
// and the function that shows it. The first view is the present view, so the
// rules of the whole document run one time for it. The animations take no
// time during the check, because a color in the middle of a transition can
// fail a rule of contrast.
export async function accessibility(
  steps: readonly { slide: number; step: number }[],
  show: (index: number) => void,
  views: readonly (readonly [string, () => void])[],
  axe: Axe,
): Promise<Finding[]> {
  const root = document.documentElement.style;
  root.setProperty("--dur", "0s");
  root.setProperty("--motion", "0");
  const findings: Finding[] = [];
  const read = async (
    where: string,
    context: Document | Element,
  ): Promise<void> => {
    const result = await axe.run(context, OPTIONS);
    for (const violation of result.violations) {
      findings.push({
        where,
        rule: violation.id,
        help: violation.help,
        targets: violation.nodes.map((node) => node.target.join(" ")),
      });
    }
  };
  try {
    for (const [index, { slide, step }] of steps.entries()) {
      show(index);
      const element = document.getElementById(`slide-${slide}`);
      if (element !== null) {
        await read(`Slide ${slide}, step ${step}`, element);
      }
    }
    for (const [name, open] of views) {
      open();
      await read(name, document);
    }
  } finally {
    root.removeProperty("--dur");
    root.removeProperty("--motion");
  }
  return first(findings);
}

// Write the result into an element `check-result`, and set `data-check` on
// the `body` to `done`. The JSON escapes each `<`, so a text of the deck
// cannot close the element.
export function write(result: Result): void {
  const element = document.createElement("script");
  element.type = "application/json";
  element.id = "check-result";
  element.textContent = JSON.stringify(result).replace(/</g, "\\u003c");
  document.body.append(element);
  document.body.dataset.check = "done";
}
