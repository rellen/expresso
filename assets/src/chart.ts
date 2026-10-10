// The numbers of a chart with the `count` option. `Expresso.Element.Chart.Motion`
// writes each number as a `tspan` with the class `chart-count`, and the style
// sheet moves its registered property `--chart-n` from the value of one frame
// to the value of the next, with the time and the easing of the element. This
// module writes the value of the property as the text of the number at each
// frame of the browser, so the number counts while the marks move.
//
// The style sheet sets the time, so a reader who asks for reduced motion and
// a deck with the speed `:instant` see the new number at once, and the module
// needs no rule of its own for them.

// One number of a chart. `data-decimals` gives the most decimals of its values.
export interface Count {
  textContent: string | null;
  dataset: { decimals?: string };
}

// Write a number as `Expresso.Element.Chart.Plot.label/1` does: with no more
// decimals than the values of the chart, and with no zero at the end of the
// fraction.
export function format(value: number, decimals: number): string {
  const text = value.toFixed(decimals);
  const trimmed = text.includes(".") ? text.replace(/\.?0+$/, "") : text;
  return trimmed === "-0" ? "0" : trimmed;
}

// Write the current value of each number. `read` returns the value of
// `--chart-n`. The function returns true when a text changed.
export function write<T extends Count>(
  counts: Iterable<T>,
  read: (count: T) => string,
): boolean {
  let changed = false;
  for (const count of counts) {
    const value = Number.parseFloat(read(count));
    if (Number.isNaN(value)) {
      continue;
    }
    const text = format(value, Number(count.dataset.decimals ?? "0"));
    if (count.textContent !== text) {
      count.textContent = text;
      changed = true;
    }
  }
  return changed;
}

let frame: number | null = null;

// Write the numbers at each frame of the browser while a transition of a
// number runs. The new step starts the transitions at a later frame, so the
// run waits a few frames for them. A call during a run changes nothing, and
// a document without such a number starts no run.
export function count(): void {
  if (
    frame !== null ||
    document.querySelectorAll(".chart-count").length === 0
  ) {
    return;
  }
  let waited = 0;
  const run = (): void => {
    const counts = Array.from(
      document.querySelectorAll<SVGTSpanElement>(".chart-count"),
    );
    write(counts, (count) =>
      getComputedStyle(count).getPropertyValue("--chart-n"),
    );
    const running = counts.some((count) => count.getAnimations().length > 0);
    waited = running ? 0 : waited + 1;
    frame = waited < 3 ? requestAnimationFrame(run) : null;
  };
  frame = requestAnimationFrame(run);
}
