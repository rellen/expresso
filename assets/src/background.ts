// The contrast of the text of a slide on the background of the slide, for the
// accessibility check of `?check=a11y`.
//
// The `background` option of a slide puts an image, a color or a gradient
// behind the content of the slide, and a dim layer over it. axe-core does not
// give a contrast for a text on an image or on a gradient. Thus this module
// draws the background of the slide on a canvas, as the style sheet shows it,
// and it compares the color of each text with the pixels behind the text.
//
// The canvas is not more than 480 pixels wide. One pixel of the canvas is
// then the mean of a small area of the slide, so one bright point of a photo
// does not fail a text.

import { owner } from "./layout.ts";

// A color as red, green and blue, each from 0 to 255.
export type Rgb = readonly [number, number, number];

// A box with a place and a size.
export type Box = Readonly<{
  x: number;
  y: number;
  width: number;
  height: number;
}>;

// The most pixels in the width of the canvas.
export const WIDTH = 480;

// The id and the help text of the rule, as a rule of axe-core has them.
export const RULE = "background-contrast";
export const HELP =
  "Text must have a contrast of 4.5:1 on the background of its slide, or 3:1 for large text. " +
  "Give the background option a higher dim";

// The relative luminance of a color, as WCAG 2.2 defines it.
export function luminance(color: Rgb): number {
  const [red, green, blue] = color.map((channel) => {
    const value = channel / 255;
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  }) as [number, number, number];
  return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
}

// The contrast ratio of two colors, from 1 to 21.
export function contrast(a: Rgb, b: Rgb): number {
  const [low, high] = [luminance(a), luminance(b)].sort((x, y) => x - y) as [
    number,
    number,
  ];
  return (high + 0.05) / (low + 0.05);
}

// A color of a computed style: `rgb(1, 2, 3)`, `rgba(1, 2, 3, 0.5)` or
// `color(srgb 0.1 0.2 0.3 / 0.5)`. The function returns null for a text that
// is not one of these forms.
export function parseColor(text: string): { rgb: Rgb; alpha: number } | null {
  const rgb =
    /^rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)(?:\s*[,/]\s*([\d.]+%?))?\s*\)$/.exec(
      text.trim(),
    );
  if (rgb !== null) {
    return {
      rgb: [Number(rgb[1]), Number(rgb[2]), Number(rgb[3])],
      alpha: alpha(rgb[4]),
    };
  }
  const srgb =
    /^color\(srgb\s+([\d.e-]+)\s+([\d.e-]+)\s+([\d.e-]+)(?:\s*\/\s*([\d.]+%?))?\s*\)$/.exec(
      text.trim(),
    );
  if (srgb !== null) {
    const channel = (value: string | undefined): number =>
      Math.round(Math.min(Math.max(Number(value), 0), 1) * 255);
    return {
      rgb: [channel(srgb[1]), channel(srgb[2]), channel(srgb[3])],
      alpha: alpha(srgb[4]),
    };
  }
  return null;
}

function alpha(text: string | undefined): number {
  if (text === undefined) {
    return 1;
  }
  return text.endsWith("%") ? Number(text.slice(0, -1)) / 100 : Number(text);
}

// The box of an image in a container, with the `object-fit` and the
// `object-position` of the style sheet. `position` is the part of the free
// space in front of the image in each direction, from 0 to 1, so `[0.5, 0.5]`
// puts the image in the center.
export function placed(
  container: Readonly<{ width: number; height: number }>,
  image: Readonly<{ width: number; height: number }>,
  fit: "cover" | "contain",
  position: readonly [number, number],
): Box {
  const scales = [
    container.width / image.width,
    container.height / image.height,
  ] as const;
  const scale = fit === "cover" ? Math.max(...scales) : Math.min(...scales);
  const width = image.width * scale;
  const height = image.height * scale;
  return {
    x: (container.width - width) * position[0],
    y: (container.height - height) * position[1],
    width,
    height,
  };
}

// The two parts of a computed `object-position`, such as `50% 0%`, as parts
// of the free space. A part that is not a percentage gives the center.
export function parsePosition(text: string): [number, number] {
  const parts = text.trim().split(/\s+/);
  const part = (value: string | undefined): number =>
    value !== undefined && value.endsWith("%")
      ? Number(value.slice(0, -1)) / 100
      : 0.5;
  return [part(parts[0]), part(parts[1])];
}

// The start and the end of the line of a CSS linear gradient in a box. An
// angle of 0 degrees goes to the top, and an angle of 90 degrees goes to the
// right, as CSS defines it.
export function gradientLine(
  width: number,
  height: number,
  degrees: number,
): Readonly<{ x0: number; y0: number; x1: number; y1: number }> {
  const angle = (degrees * Math.PI) / 180;
  const length =
    Math.abs(width * Math.sin(angle)) + Math.abs(height * Math.cos(angle));
  const dx = (Math.sin(angle) * length) / 2;
  const dy = (-Math.cos(angle) * length) / 2;
  return {
    x0: width / 2 - dx,
    y0: height / 2 - dy,
    x1: width / 2 + dx,
    y1: height / 2 + dy,
  };
}

// The angle and the colors of a computed `background-image` that is a linear
// gradient of the `background` option, or null. The renderer writes the angle
// in degrees and no place for a color, so the colors are at equal distances.
export function parseGradient(
  text: string,
): { degrees: number; colors: string[] } | null {
  const match = /^linear-gradient\(\s*(-?[\d.]+)deg\s*,(.*)\)$/s.exec(
    text.trim(),
  );
  if (match === null) {
    return null;
  }
  const colors = (match[2] ?? "").match(/(rgba?|color)\([^)]*\)/g) ?? [];
  return colors.length < 2 ? null : { degrees: Number(match[1]), colors };
}

// The minimum contrast of a text: 3 for large text, and 4.5 for each other
// text. Large text is 24 px or more, or 18.66 px or more in bold, which is 18
// points and 14 points.
export function minimum(size: number, weight: number): number {
  return size >= 24 || (size >= 18.66 && weight >= 700) ? 3 : 4.5;
}

// The lowest contrast of a color on the pixels of an area. `pixels` holds
// red, green, blue and alpha for each pixel, as `ImageData` does. An area
// with no pixel returns the highest contrast.
export function lowest(color: Rgb, pixels: ArrayLike<number>): number {
  let low = 21;
  for (let index = 0; index + 3 < pixels.length; index += 4) {
    const pixel: Rgb = [
      pixels[index] ?? 0,
      pixels[index + 1] ?? 0,
      pixels[index + 2] ?? 0,
    ];
    low = Math.min(low, contrast(color, pixel));
  }
  return low;
}

// A color of a computed style that the canvas can draw, or null for a color
// with no opacity.
function solid(text: string): string | null {
  const color = parseColor(text);
  return color === null || color.alpha === 0 ? null : text;
}

// The first color under the background of the slide that has an opacity: the
// color of the slide, of an element around it, or white.
function base(slide: Element): string {
  for (
    let element: Element | null = slide;
    element !== null;
    element = element.parentElement
  ) {
    const color = solid(getComputedStyle(element).backgroundColor);
    if (color !== null) {
      return color;
    }
  }
  return "rgb(255, 255, 255)";
}

// Draw the layers of the background of a slide, in the order of the document.
//
// The function does not wait for a promise. The check runs in a browser with
// a virtual clock, and that clock does not wait for the decode of an image, so
// the browser can end before a promise of `decode()` settles. The document
// holds each image as a data URI, so the image is complete at the load of the
// document, and the canvas decodes it when it draws it.
function draw(
  context: CanvasRenderingContext2D,
  background: Element,
  width: number,
  height: number,
): void {
  for (const layer of Array.from(background.children)) {
    const style = getComputedStyle(layer);
    context.globalAlpha = Number(style.opacity);
    if (layer instanceof HTMLImageElement) {
      if (layer.complete && layer.naturalWidth > 0 && layer.naturalHeight > 0) {
        const box = placed(
          { width, height },
          { width: layer.naturalWidth, height: layer.naturalHeight },
          style.objectFit === "contain" ? "contain" : "cover",
          parsePosition(style.objectPosition),
        );
        context.drawImage(layer, box.x, box.y, box.width, box.height);
      }
      continue;
    }
    const gradient = parseGradient(style.backgroundImage);
    if (gradient !== null) {
      const line = gradientLine(width, height, gradient.degrees);
      const fill = context.createLinearGradient(
        line.x0,
        line.y0,
        line.x1,
        line.y1,
      );
      gradient.colors.forEach((color, index) => {
        fill.addColorStop(index / (gradient.colors.length - 1), color);
      });
      context.fillStyle = fill;
      context.fillRect(0, 0, width, height);
      continue;
    }
    const color = solid(style.backgroundColor);
    if (color !== null) {
      context.fillStyle = color;
      context.fillRect(0, 0, width, height);
    }
  }
  context.globalAlpha = 1;
}

// Tell if an element or an element around it, inside the slide, has a
// background of its own. Such a text is not on the background of the slide,
// and axe-core measures it.
function covered(element: Element, slide: Element): boolean {
  for (
    let each: Element | null = element;
    each !== null && each !== slide;
    each = each.parentElement
  ) {
    const style = getComputedStyle(each);
    if (
      solid(style.backgroundColor) !== null ||
      style.backgroundImage !== "none"
    ) {
      return true;
    }
  }
  return false;
}

// The name of an element for the report: the name that the layout check
// gives, or the start of its text for a part of a template, such as a
// heading.
function nameOf(element: Element): string {
  const name = owner(element);
  if (name !== null) {
    return `the ${name}`;
  }
  const text = (element.textContent ?? "").replace(/\s+/g, " ").trim();
  return `the text “${text.length > 30 ? `${text.slice(0, 30)}…` : text}”`;
}

// Return the name of each element of a slide whose text has less than its
// minimum contrast on the background of the slide. A slide with no
// `background` option returns no name. A text that does not show, and a text
// on a background of its own, are not in the result.
export function measure(slide: Element): string[] {
  const background = slide.querySelector(":scope > .slide-background");
  const area = slide.getBoundingClientRect();
  if (background === null || area.width === 0 || area.height === 0) {
    return [];
  }
  const scale = Math.min(1, WIDTH / area.width);
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(1, Math.round(area.width * scale));
  canvas.height = Math.max(1, Math.round(area.height * scale));
  const context = canvas.getContext("2d", { willReadFrequently: true });
  if (context === null) {
    return [];
  }
  context.fillStyle = base(slide);
  context.fillRect(0, 0, canvas.width, canvas.height);
  draw(context, background, canvas.width, canvas.height);

  const names: string[] = [];
  const range = document.createRange();
  const walker = document.createTreeWalker(slide, NodeFilter.SHOW_TEXT);
  for (let node = walker.nextNode(); node !== null; node = walker.nextNode()) {
    const element = node.parentElement;
    if (
      element === null ||
      (node.textContent ?? "").trim() === "" ||
      background.contains(element) ||
      element.closest(".slide-hidden-heading") !== null ||
      element.checkVisibility?.({
        opacityProperty: true,
        visibilityProperty: true,
      }) === false ||
      covered(element, slide)
    ) {
      continue;
    }
    const style = getComputedStyle(element);
    const color = parseColor(style.color);
    if (color === null) {
      continue;
    }
    const least = minimum(
      Number.parseFloat(style.fontSize),
      Number(style.fontWeight),
    );
    range.selectNodeContents(node);
    const failed = Array.from(range.getClientRects()).some((rect) => {
      const left = Math.max(0, Math.floor((rect.left - area.left) * scale));
      const top = Math.max(0, Math.floor((rect.top - area.top) * scale));
      const right = Math.min(
        canvas.width,
        Math.ceil((rect.right - area.left) * scale),
      );
      const bottom = Math.min(
        canvas.height,
        Math.ceil((rect.bottom - area.top) * scale),
      );
      if (right <= left || bottom <= top) {
        return false;
      }
      const pixels = context.getImageData(
        left,
        top,
        right - left,
        bottom - top,
      ).data;
      return lowest(color.rgb, pixels) < least;
    });
    const name = nameOf(element);
    if (failed && !names.includes(name)) {
      names.push(name);
    }
  }
  return names;
}
