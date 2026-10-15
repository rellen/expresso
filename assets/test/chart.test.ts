import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { format, formatStat, write } from "../src/chart.ts";
import type { Count, Reading } from "../src/chart.ts";

// The numbers and their texts from Elixir. `Expresso.Test.NumberFixtures`
// tells how to write the file again.
type Numbers = {
  charts: { numbers: number[]; decimals: number; labels: string[] }[];
  stats: { value: number; decimals: number; group: boolean; text: string }[];
};

const numbers: Numbers = JSON.parse(
  readFileSync(new URL("./fixtures/numbers.json", import.meta.url), "utf8"),
);

test("format writes each number of a chart as Plot.label/1 does", () => {
  for (const chart of numbers.charts) {
    assert.deepEqual(
      chart.numbers.map((value) => format(value, chart.decimals)),
      chart.labels,
    );
  }
});

test("formatStat writes each number of a stat as Stat.format/3 does", () => {
  for (const stat of numbers.stats) {
    assert.equal(
      formatStat(stat.value, stat.decimals, stat.group),
      stat.text,
      JSON.stringify(stat),
    );
  }
});

// A frame of a count can have more decimals than the chart.
test("a number has the decimals of the chart, with no zero at the end of the fraction", () => {
  assert.equal(format(12.3456, 1), "12.3");
  assert.equal(format(40.0001, 1), "40");
  assert.equal(format(25.5, 2), "25.5");
  assert.equal(format(7.6, 0), "8");
  assert.equal(format(-0.01, 1), "0");
  assert.equal(format(-5, 0), "-5");
  assert.equal(format(1250, 0), "1250");
});

function count(text: string, decimals?: string): Count {
  return {
    textContent: text,
    dataset: decimals === undefined ? {} : { decimals },
  };
}

function moving(value: number): () => Reading {
  return () => ({ value, moving: true });
}

function still(value: number): () => Reading {
  return () => ({ value, moving: false });
}

test("write puts the value of each moving number into its text, and tells whether a text changed", () => {
  const counts = [count("10", "1"), count("3")];
  const values = new Map<Count, number>([
    [counts[0]!, 11.27],
    [counts[1]!, 3],
  ]);
  const read = (one: Count): Reading => ({
    value: values.get(one) ?? Number.NaN,
    moving: true,
  });

  assert.equal(write(counts, read), true);
  assert.deepEqual(
    counts.map((one) => one.textContent),
    ["11.3", "3"],
  );
  assert.equal(write(counts, read), false);
});

test("write keeps the text of a number without a value", () => {
  const counts = [count("10")];
  assert.equal(write(counts, still(Number.NaN)), false);
  assert.equal(counts[0]!.textContent, "10");
});

test("write uses the format of a stat for a number with data-group", () => {
  const stat: Count = {
    textContent: "0",
    dataset: { decimals: "0", group: "true" },
  };
  assert.equal(write([stat], moving(1249.6)), true);
  assert.equal(stat.textContent, "1,250");
});

// Chromium writes the value 1234567 of `--chart-n` as `1.23457e+06`.
function bigStat(): Count {
  return {
    textContent: "5",
    dataset: { decimals: "0", group: "true", texts: '["5","1,234,567"]' },
  };
}

test("a number at rest gets the text from data-texts with the nearest value", () => {
  const stat = bigStat();
  assert.equal(write([stat], still(1234570)), true);
  assert.equal(stat.textContent, "1,234,567");
  assert.equal(write([stat], still(5)), true);
  assert.equal(stat.textContent, "5");

  const chart: Count = {
    textContent: "0",
    dataset: { decimals: "1", texts: '["0","2.5","1250"]' },
  };
  assert.equal(write([chart], still(1249.99)), true);
  assert.equal(chart.textContent, "1250");
  assert.equal(write([chart], still(2.50001)), true);
  assert.equal(chart.textContent, "2.5");
});

test("a moving number gets its value, not a text from data-texts", () => {
  const stat = bigStat();
  assert.equal(write([stat], moving(1234570)), true);
  assert.equal(stat.textContent, "1,234,570");
});

test("a number at rest without data-texts gets its value", () => {
  const counts = [count("0", "1")];
  assert.equal(write(counts, still(12.34)), true);
  assert.equal(counts[0]!.textContent, "12.3");
});
