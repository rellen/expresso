import { test } from "node:test";
import assert from "node:assert/strict";
import { format, write } from "../src/chart.ts";
import type { Count } from "../src/chart.ts";

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

test("write puts the value of each number into its text, and tells whether a text changed", () => {
  const counts = [count("10", "1"), count("3")];
  const values = new Map<Count, string>([
    [counts[0]!, " 11.27"],
    [counts[1]!, "3"],
  ]);
  const read = (one: Count): string => values.get(one) ?? "";

  assert.equal(write(counts, read), true);
  assert.deepEqual(
    counts.map((one) => one.textContent),
    ["11.3", "3"],
  );
  assert.equal(write(counts, read), false);
});

test("write keeps the text of a number without a value", () => {
  const counts = [count("10")];
  assert.equal(
    write(counts, () => ""),
    false,
  );
  assert.equal(counts[0]!.textContent, "10");
});
