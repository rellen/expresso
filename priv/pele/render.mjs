// The script that draws a Mermaid diagram with Pele, for
// `Expresso.Element.Diagram.Pele`. Node runs it with one argument: a private
// directory that holds `source.mmd` and `options.json`. The script writes
// `graph.json` into the same directory, with the SVG, the type of the diagram
// and the model of `parse()`. A diagram that Pele cannot draw ends the script
// with the status 1 and the message of Pele on the standard error.
//
// `options.json` holds the family of the font and the advance width of each
// character of the font, from `Expresso.Element.Diagram.Font.advances/2`. The
// measurer gives Pele the width of a text from those widths, so each box fits
// its text in the font of the slide. A monospace text takes 0.6 of the size
// for each character, and a character with no width takes the default width.

import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { parse, render } from "./pele.js";

const dir = process.argv[2];
const source = readFileSync(join(dir, "source.mmd"), "utf8");
const options = JSON.parse(readFileSync(join(dir, "options.json"), "utf8"));

// The width of a character that the font does not have, and of each character
// of a monospace text, as a part of the size of the font.
const DEFAULT_WIDTH = 0.6;

// The style of Pele is a set of bits: 1 bold, 2 italic and 4 monospace.
function measurer(widths) {
  return {
    width(text, size, style) {
      const table = widths[String(style & 3)] ?? widths["0"];
      let total = 0;
      for (const character of text) {
        const width = style & 4 ? undefined : table[character.codePointAt(0)];
        total += width ?? DEFAULT_WIDTH;
      }
      return total * size;
    },
  };
}

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
    measurer: options.widths ? measurer(options.widths) : undefined,
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
