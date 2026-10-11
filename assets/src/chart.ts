// The numbers that count: the numbers of a chart with the `count` option, and
// the number of a stat with the `count` option. `Expresso.Element.Chart.Motion`
// writes each number of a chart as a `tspan` with the class `chart-count`, and
// `Expresso.Element.Stat` writes the number of a stat as a `span` with the
// class `stat-count`. The style sheet moves their registered property
// `--chart-n`, with the time and the easing of the element. This module writes
// the value of the property as the text of the number at each frame of the
// browser, so the number counts while the property moves.
//
// The style sheet sets the time, so a reader who asks for reduced motion and
// a deck with the speed `:instant` see the new number at once, and the module
// needs no rule of its own for them.

// One number that counts: a number of a chart, or the number of a stat.
// `data-decimals` gives the decimals. A stat has `data-group`, and it keeps
// each decimal and puts a comma between each group of three digits.
export interface Count {
  textContent: string | null;
  dataset: { decimals?: string; group?: string };
}

// The numbers that count, in the whole document. The query takes one class at
// a time, as the fake document of the tests does.
function counts(): (HTMLElement | SVGTSpanElement)[] {
  return [".chart-count", ".stat-count"].flatMap((selector) =>
    Array.from(
      document.querySelectorAll<HTMLElement | SVGTSpanElement>(selector),
    ),
  );
}

// Write a number as `Expresso.Element.Chart.Plot.label/1` does: with no more
// decimals than the values of the chart, and with no zero at the end of the
// fraction.
export function format(value: number, decimals: number): string {
  const text = value.toFixed(decimals);
  const trimmed = text.includes(".") ? text.replace(/\.?0+$/, "") : text;
  return trimmed === "-0" ? "0" : trimmed;
}

// Write a number as `Expresso.Element.Stat.format/3` does: with each decimal,
// and with a comma between each group of three digits when `group` is true.
export function formatStat(
  value: number,
  decimals: number,
  group: boolean,
): string {
  const text = Math.abs(value).toFixed(decimals);
  const [whole = "", fraction] = text.split(".");
  const grouped = group ? whole.replace(/\B(?=(\d{3})+(?!\d))/g, ",") : whole;
  const zero = /^[0.]*$/.test(text);
  const sign = value < 0 && !zero ? "-" : "";
  return sign + grouped + (fraction === undefined ? "" : "." + fraction);
}

function text<T extends Count>(count: T, value: number): string {
  const decimals = Number(count.dataset.decimals ?? "0");
  return count.dataset.group === undefined
    ? format(value, decimals)
    : formatStat(value, decimals, count.dataset.group === "true");
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
    const written = text(count, value);
    if (count.textContent !== written) {
      count.textContent = written;
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
  if (frame !== null || counts().length === 0) {
    return;
  }
  let waited = 0;
  const run = (): void => {
    const numbers = counts();
    write(numbers, (count) =>
      getComputedStyle(count).getPropertyValue("--chart-n"),
    );
    const running = numbers.some((count) => count.getAnimations().length > 0);
    waited = running ? 0 : waited + 1;
    frame = waited < 3 ? requestAnimationFrame(run) : null;
  };
  frame = requestAnimationFrame(run);
}
