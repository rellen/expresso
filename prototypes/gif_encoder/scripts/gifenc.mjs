// The baseline: encode the frames of each animation with gifenc, as
// assets/gifs/record.ts does, and print the time of the encoding.
//
//     node scripts/gifenc.mjs <frames directory> <output directory>
//
// Each subdirectory of the frames directory holds 000.png, 001.png, ... and
// delays.json. gifenc and pngjs come from node_modules of Expresso.

import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import gifenc from "gifenc";
import pngjs from "pngjs";

const [framesDirectory, outputDirectory] = process.argv.slice(2);
mkdirSync(outputDirectory, { recursive: true });
const { GIFEncoder, applyPalette, quantize } = gifenc;
const { PNG } = pngjs;

let total = 0;
for (const name of readdirSync(framesDirectory).sort()) {
  const dir = join(framesDirectory, name);
  const delays = JSON.parse(readFileSync(join(dir, "delays.json"), "utf8"));
  const pngs = delays.map((_, i) => readFileSync(join(dir, String(i).padStart(3, "0") + ".png")));
  const start = performance.now();
  const gif = GIFEncoder();
  pngs.forEach((png, i) => {
    const { width, height, data } = PNG.sync.read(png);
    const palette = quantize(data, 256);
    gif.writeFrame(applyPalette(data, palette), width, height, { palette, delay: delays[i] });
  });
  gif.finish();
  const bytes = gif.bytes();
  total += performance.now() - start;
  writeFileSync(join(outputDirectory, `${name}.gif`), bytes);
}
console.log(JSON.stringify({ milliseconds: Math.round(total) }));
