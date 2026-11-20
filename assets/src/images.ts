// The images that keep their file next to the document.
//
// The renderer writes `loading="lazy"` on the `img` element of an image with
// `external true`, and `Expresso.Element.Image` gives the rule. The browser
// then asks for the file of such an image only when the image comes near the
// window. A deck with many photographs thus does not ask for each file when
// it loads the document. An image in a data URI has no attribute, because the
// document holds its file.
//
// The presenter asks for the other files at three times:
//
// - When the browser is idle after the load of the document, `main.ts` calls
//   `load` with `idle`. The files then come in the background. A jump to a
//   far slide before that time can show its image late.
// - The handout view and a print show each page, so `main.ts` calls `load`
//   for the handout view and at the event `beforeprint`.
// - The layout check measures the size of each image, so it waits for `load`
//   before it measures. A lazy image has no size before the browser has its
//   file.
//
// `load` sets `loading` to `eager` on each such image, and it waits until
// each image is complete. The attribute stays on the element, so the selector
// finds the image also after the change.
//
// `load` does not wait for `decode()`. A complete image has its size, so the
// layout check needs no more. The browser decodes an image when it paints or
// prints it. The headless browser of `mix expresso --check` runs the page in
// virtual time, and a decode does not stop that time. In a test, the time of
// the check ended before each decode, and the page wrote no result. A decode
// of each photograph of a deck also keeps each one in memory.

// The images with a file next to the document. Only the renderer writes the
// attribute `loading`.
export const SELECTOR = "img[loading]";

// The time in milliseconds that the browser can wait for an idle period
// before it calls the function of `idle`.
export const LIMIT = 5000;

// The time in milliseconds after which `idle` calls its function in a browser
// with no `requestIdleCallback`.
export const FALLBACK = 1000;

// The part of an `img` element that this module uses.
export type Image = {
  loading: string;
  readonly complete: boolean;
  addEventListener(
    type: "load" | "error",
    listener: () => void,
    options: { once: boolean },
  ): void;
};

// The functions of the window that `idle` uses. A browser with no
// `requestIdleCallback` has `setTimeout` only.
export type Scheduler = {
  requestIdleCallback?: (
    callback: () => void,
    options: { timeout: number },
  ) => unknown;
  setTimeout(callback: () => void, delay: number): unknown;
};

// Wait until an image is complete. An image with no file, such as a copy that
// is not next to the document, sends the event `error`, and it is then
// complete and broken. The promise resolves for it too, so one missing file
// does not stop a check.
export function ready(image: Image): Promise<void> {
  if (image.complete) {
    return Promise.resolve();
  }
  return new Promise<void>((resolve) => {
    image.addEventListener("load", () => resolve(), { once: true });
    image.addEventListener("error", () => resolve(), { once: true });
  });
}

// Ask for the file of each image now, and wait until each image is ready.
// The change from `lazy` to `eager` makes the browser ask for the file, also
// for an image of a slide that does not show.
export function request(images: readonly Image[]): Promise<void> {
  for (const image of images) {
    if (image.loading === "lazy") {
      image.loading = "eager";
    }
  }
  return Promise.all(images.map(ready)).then(() => undefined);
}

// The promise of the first call of `load`. The document does not get a new
// image after the load, so each later call returns the same promise.
let loading: Promise<void> | null = null;

// Ask for the file of each image of the document that has one next to the
// document, and wait until each image is ready.
export function load(): Promise<void> {
  loading ??= request(
    Array.from(document.querySelectorAll<HTMLImageElement>(SELECTOR)),
  );
  return loading;
}

// Call a function when the browser is idle, or after `LIMIT` milliseconds of
// a busy browser. A browser with no `requestIdleCallback` calls it after
// `FALLBACK` milliseconds.
export function idle(
  callback: () => void,
  scheduler: Scheduler = globalThis as unknown as Scheduler,
): void {
  if (typeof scheduler.requestIdleCallback === "function") {
    scheduler.requestIdleCallback(() => callback(), { timeout: LIMIT });
  } else {
    scheduler.setTimeout(callback, FALLBACK);
  }
}
