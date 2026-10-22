// The script that draws a Mermaid diagram with Pele, for
// `Expresso.Element.Diagram.Pele`. Node runs it with one argument: a private
// directory that holds `source.mmd` and `options.json`. The script writes
// `graph.json` into the same directory, with the SVG, the type of the diagram
// and the model of `parse()`. A diagram that Pele cannot draw ends the script
// with the status 1 and the message of Pele on the standard error.

import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { parse, render } from "./pele.js";

const dir = process.argv[2];
const source = readFileSync(join(dir, "source.mmd"), "utf8");
const options = JSON.parse(readFileSync(join(dir, "options.json"), "utf8"));

// A map and a set of the model become an object and a list in the JSON.
function plain(_key, value) {
  if (value instanceof Map) return Object.fromEntries(value);
  if (value instanceof Set) return [...value];
  return value;
}

try {
  const result = render(source, {
    idPrefix: "pele",
    responsive: false,
    autoDirection: false,
    fontFamily: options.fontFamily,
  });

  writeFileSync(
    join(dir, "graph.json"),
    JSON.stringify(
      { svg: result.svg, type: result.type, model: parse(source) },
      plain,
    ),
  );
} catch (error) {
  process.stderr.write(`${error?.message ?? error}\n`);
  process.exit(1);
}
