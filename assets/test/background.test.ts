import { test } from "node:test";
import assert from "node:assert/strict";
import {
  contrast,
  gradientLine,
  lowest,
  luminance,
  minimum,
  parseColor,
  parseGradient,
  parsePosition,
  placed,
} from "../src/background.ts";

// Round to two decimal places. The sum with 0 changes -0 into 0.
function round(value: number): number {
  return Math.round(value * 100) / 100 + 0;
}

test("luminance gives 0 for black and 1 for white", () => {
  assert.equal(luminance([0, 0, 0]), 0);
  assert.equal(round(luminance([255, 255, 255])), 1);
  assert.equal(round(luminance([255, 0, 0])), 0.21);
});

test("contrast gives the ratio of WCAG, in the two orders", () => {
  assert.equal(contrast([0, 0, 0], [255, 255, 255]), 21);
  assert.equal(contrast([255, 255, 255], [0, 0, 0]), 21);
  assert.equal(contrast([10, 20, 30], [10, 20, 30]), 1);
  // The grey #777777 on white is the common example under 4.5:1.
  assert.equal(round(contrast([119, 119, 119], [255, 255, 255])), 4.48);
});

test("parseColor reads the colors of a computed style", () => {
  assert.deepEqual(parseColor("rgb(1, 2, 3)"), { rgb: [1, 2, 3], alpha: 1 });
  assert.deepEqual(parseColor("rgba(1, 2, 3, 0.5)"), {
    rgb: [1, 2, 3],
    alpha: 0.5,
  });
  assert.deepEqual(parseColor("rgb(1 2 3 / 50%)"), {
    rgb: [1, 2, 3],
    alpha: 0.5,
  });
  assert.deepEqual(parseColor("rgba(0, 0, 0, 0)"), {
    rgb: [0, 0, 0],
    alpha: 0,
  });
  assert.deepEqual(parseColor("color(srgb 1 0.5 0)"), {
    rgb: [255, 128, 0],
    alpha: 1,
  });
  assert.deepEqual(parseColor("color(srgb 0.2 0.4 0.6 / 0.25)"), {
    rgb: [51, 102, 153],
    alpha: 0.25,
  });
  assert.equal(parseColor("transparent"), null);
  assert.equal(parseColor("linear-gradient(red, blue)"), null);
});

test("placed gives the box of an image that covers its container", () => {
  // A square image in a wide container: the image is as wide as the
  // container, and the container cuts its top and its bottom.
  assert.deepEqual(
    placed(
      { width: 400, height: 200 },
      { width: 100, height: 100 },
      "cover",
      [0.5, 0.5],
    ),
    { x: 0, y: -100, width: 400, height: 400 },
  );
  // With the position at the top, the container cuts only the bottom.
  assert.deepEqual(
    placed(
      { width: 400, height: 200 },
      { width: 100, height: 100 },
      "cover",
      [0.5, 0],
    ),
    { x: 0, y: -0, width: 400, height: 400 },
  );
});

test("placed gives the box of an image that the container contains", () => {
  assert.deepEqual(
    placed(
      { width: 400, height: 200 },
      { width: 100, height: 100 },
      "contain",
      [0.5, 0.5],
    ),
    { x: 100, y: 0, width: 200, height: 200 },
  );
  assert.deepEqual(
    placed(
      { width: 400, height: 200 },
      { width: 100, height: 100 },
      "contain",
      [1, 1],
    ),
    { x: 200, y: 0, width: 200, height: 200 },
  );
});

test("parsePosition reads the two percentages of a computed position", () => {
  assert.deepEqual(parsePosition("50% 50%"), [0.5, 0.5]);
  assert.deepEqual(parsePosition("100% 0%"), [1, 0]);
  assert.deepEqual(parsePosition("20% 80%"), [0.2, 0.8]);
  // A length is not a part of the free space, so it gives the center.
  assert.deepEqual(parsePosition("10px 20px"), [0.5, 0.5]);
});

test("gradientLine gives the line of CSS for an angle", () => {
  const points = (degrees: number): number[] => {
    const line = gradientLine(400, 200, degrees);
    return [line.x0, line.y0, line.x1, line.y1].map(round);
  };

  // 180 degrees goes from the top to the bottom, and 0 degrees goes up.
  assert.deepEqual(points(180), [200, 0, 200, 200]);
  assert.deepEqual(points(0), [200, 200, 200, 0]);
  // 90 degrees goes from the left to the right.
  assert.deepEqual(points(90), [0, 100, 400, 100]);
  // At 135 degrees, the line goes through the center to the lower right, and
  // it is long enough for the two corners.
  const [x0, y0, x1, y1] = points(135) as [number, number, number, number];
  assert.ok(x0 < 200 && y0 < 100 && x1 > 200 && y1 > 100);
  assert.equal(round(x0 + x1), 400);
  assert.equal(round(y0 + y1), 200);
});

test("parseGradient reads the angle and the colors of a computed gradient", () => {
  assert.deepEqual(
    parseGradient(
      "linear-gradient(135deg, rgb(52, 101, 164), rgb(255, 255, 255))",
    ),
    { degrees: 135, colors: ["rgb(52, 101, 164)", "rgb(255, 255, 255)"] },
  );
  assert.deepEqual(
    parseGradient(
      "linear-gradient(90deg, rgb(0, 0, 0), color(srgb 0.5 0.5 0.5), rgba(1, 2, 3, 0.5))",
    ),
    {
      degrees: 90,
      colors: ["rgb(0, 0, 0)", "color(srgb 0.5 0.5 0.5)", "rgba(1, 2, 3, 0.5)"],
    },
  );
  assert.equal(parseGradient("none"), null);
  assert.equal(parseGradient("url(photo.jpg)"), null);
  assert.equal(parseGradient("linear-gradient(90deg, rgb(0, 0, 0))"), null);
});

test("minimum gives 3 for large text and 4.5 for each other text", () => {
  assert.equal(minimum(24, 400), 3);
  assert.equal(minimum(23.9, 400), 4.5);
  assert.equal(minimum(18.66, 700), 3);
  assert.equal(minimum(18.66, 400), 4.5);
  assert.equal(minimum(16, 700), 4.5);
});

test("lowest gives the lowest contrast of a color on the pixels of an area", () => {
  // One white pixel and one mid-grey pixel, under black text.
  const pixels = [255, 255, 255, 255, 119, 119, 119, 255];

  assert.equal(round(lowest([0, 0, 0], pixels)), 4.69);
  assert.equal(lowest([0, 0, 0], [255, 255, 255, 255]), 21);
  assert.equal(lowest([0, 0, 0], []), 21);
});
