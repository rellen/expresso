// Record a GIF of each example deck.
//
// `mix expresso.gifs` renders each example deck to an HTML file, and it writes
// a manifest with the name, the HTML file and the keys of each example. This
// script reads the manifest, opens each HTML file in Chromium, presses the
// keys, and writes one GIF for each example:
//
//     node assets/gifs/record.ts <manifest.json> <output directory>
//
// A GIF must show each animation in the same way on each run. Therefore the
// script stops the clock of the animations of the page with the DevTools
// protocol. After a key, it moves each animation to the time of each frame,
// and it takes a screenshot of each frame. The time of the computer then has
// no effect on the frames. The environment variable `EXPRESSO_CHROMIUM` gives
// the path of a Chromium executable, as it does for the browser tests.

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { chromium } from "playwright";
import type { Page } from "playwright";
import gifenc from "gifenc";
import pngjs from "pngjs";
import { FPS, START, hold, times } from "./frames.ts";

type Example = { name: string; html: string; actions: string[] };
type Frame = { png: Buffer; delay: number };

async function shot(page: Page): Promise<Buffer> {
  return page.screenshot({ type: "png" });
}

// Wait for the animations of a key, pause them, and give the time of the
// longest one in milliseconds. A key with no animation gives 0. The page
// checks at each animation frame, and it pauses each animation at once, so an
// animation runs for one frame at most before the pause. The seek then sets
// the exact time of each frame. The page checks two more frames, because the
// browser can start a transition of the slide after the transitions of the
// overlays.
async function started(page: Page): Promise<number> {
  return page.evaluate(async () => {
    const frame = () =>
      new Promise((resolve) => requestAnimationFrame(resolve));
    const pause = () => {
      const all = document.getAnimations();
      for (const animation of all) {
        animation.pause();
      }
      return all;
    };
    let waited = 0;
    while (pause().length === 0) {
      if (waited > 500) {
        return 0;
      }
      const before = performance.now();
      await frame();
      waited += performance.now() - before;
    }
    await frame();
    await frame();
    const ends = pause().map((animation) =>
      Number(animation.effect?.getComputedTiming().endTime ?? 0),
    );
    return Math.max(0, ...ends);
  });
}

// Move each paused animation to a time, and wait for two animation frames,
// so the compositor paints the new time before the screenshot.
async function seek(page: Page, time: number): Promise<void> {
  await page.evaluate(async (time) => {
    for (const animation of document.getAnimations()) {
      animation.currentTime = time;
    }
    for (let count = 0; count < 2; count++) {
      await new Promise((resolve) => requestAnimationFrame(resolve));
    }
  }, time);
}

// Move each animation to its end, and wait until the page has no animation.
async function finish(page: Page): Promise<void> {
  await page.evaluate(() => {
    for (const animation of document.getAnimations()) {
      animation.finish();
    }
  });
  await page.waitForFunction(() => document.getAnimations().length === 0);
}

async function record(page: Page, example: Example): Promise<Frame[]> {
  await page.goto(pathToFileURL(example.html).href);
  await page.evaluate(() => document.fonts.ready);

  const frames: Frame[] = [{ png: await shot(page), delay: START }];
  for (const [index, key] of example.actions.entries()) {
    await page.keyboard.press(key);
    for (const time of times(await started(page))) {
      await seek(page, time);
      frames.push({ png: await shot(page), delay: 1000 / FPS });
    }
    await finish(page);
    const last = index === example.actions.length - 1;
    frames.push({ png: await shot(page), delay: hold(last) });
  }
  return frames;
}

// Encode the frames as one GIF that repeats with no end. Each frame gets its
// own palette of 256 colors.
function encode(frames: Frame[]): Uint8Array {
  const { GIFEncoder, applyPalette, quantize } = gifenc;
  const { PNG } = pngjs;
  const gif = GIFEncoder();
  for (const frame of frames) {
    const { width, height, data } = PNG.sync.read(frame.png);
    const palette = quantize(data, 256);
    gif.writeFrame(applyPalette(data, palette), width, height, {
      palette,
      delay: frame.delay,
    });
  }
  gif.finish();
  return gif.bytes();
}

const [manifest, output] = process.argv.slice(2);
if (manifest === undefined || output === undefined) {
  console.error("Usage: node assets/gifs/record.ts <manifest.json> <output>");
  process.exit(2);
}

const examples: Example[] = JSON.parse(readFileSync(manifest, "utf8"));
mkdirSync(output, { recursive: true });

// The GIF is 800 by 450 pixels. The slides have the layout of a window of
// 1280 by 720 pixels, and the scale of 0.625 makes each frame smaller.
const browser = await chromium.launch({
  executablePath: process.env.EXPRESSO_CHROMIUM || undefined,
});
const context = await browser.newContext({
  viewport: { width: 1280, height: 720 },
  deviceScaleFactor: 0.625,
  reducedMotion: "no-preference",
});

for (const example of examples) {
  const page = await context.newPage();
  const frames = await record(page, example);
  const path = join(output, `${example.name}.gif`);
  writeFileSync(path, encode(frames));
  console.log(`${path}: ${frames.length} frames`);
  await page.close();
}

await browser.close();
