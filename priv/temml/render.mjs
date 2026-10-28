// The script that makes MathML from LaTeX with Temml, for
// `Expresso.Element.Math.Tex`. Node runs it with one argument: a private
// directory that holds `sources.json`, a list of the LaTeX of each formula of
// a deck. The script writes `mathml.json` into the same directory, with one
// entry for each source, in the same order: `{"mathml": ...}` for a source
// that Temml reads, and `{"error": ...}` with the message of Temml for a
// source that it cannot read. One run makes each formula, so a deck starts
// Node one time.
//
// Temml trusts `\class` and `\data` only, because the parts of a formula use
// them. It refuses each other command that writes an attribute or reads a
// file, such as `\id`, `\style` and `\includegraphics`.

import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import temml from "./temml.mjs";

const dir = process.argv[2];
const sources = JSON.parse(readFileSync(join(dir, "sources.json"), "utf8"));

const TRUSTED = new Set(["\\class", "\\data"]);

const options = {
  displayMode: true,
  annotate: false,
  throwOnError: true,
  trust: (context) => TRUSTED.has(context.command),
};

const results = sources.map((source) => {
  try {
    return { mathml: temml.renderToString(source, options) };
  } catch (error) {
    return { error: `${error?.message ?? error}`.trim() };
  }
});

writeFileSync(join(dir, "mathml.json"), JSON.stringify(results));
