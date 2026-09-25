// A fake page for the tests of `main.ts`. Node has no DOM, so this module puts
// a fake `document`, `window`, `location`, `history` and `setInterval` on the
// global object.
//
// `main.ts` runs when the module loads, and it reads the page one time.
// Therefore a test file calls `fakePage` in front of the import of `main.ts`.
// Node runs each test file in its own process, so each file gets one page.

import assert from "node:assert/strict";

export type FakeElement = {
  id: string;
  className: string;
  dataset: Record<string, string | undefined>;
  style: {
    display: string;
    width?: string;
    setProperty: (name: string, value: string) => void;
    // The custom properties that `setProperty` got.
    properties: Record<string, string>;
  };
  textContent: string;
  children: FakeElement[];
  appendChild: (child: FakeElement) => void;
  replaceChildren: () => void;
  querySelector: (selector: string) => FakeElement | null;
};

// A fake window of the other side. It keeps each message that it gets.
export type FakeWindow = {
  closed: boolean;
  received: unknown[];
  postMessage: (data: unknown, origin: string) => void;
};

type Key = {
  key: string;
  ctrlKey?: boolean;
  altKey?: boolean;
  metaKey?: boolean;
};

// A click. The window of the fake page is 1200 pixels wide.
type Click = {
  clientX: number;
  button?: number;
  ctrlKey?: boolean;
  altKey?: boolean;
  metaKey?: boolean;
  shiftKey?: boolean;
  // The selector that `closest` of the target finds, as for a click on a link.
  inside?: string;
  // The page of the handout view under the click, as for a click on a slide
  // of the overview.
  on?: FakeElement;
};

// A point on the screen.
type Point = { x: number; y: number };

type Options = {
  hash?: string;
  search?: string;
  opener?: FakeWindow | null;
  // The notes of each slide, in slide order. A slide without an entry has no
  // notes.
  notes?: string[];
  // The value of `data-progress` that the renderer writes on the `body`.
  progress?: string;
  // The value of `data-duration` that the renderer writes on the `body`.
  duration?: string;
};

export type FakePage = {
  slides: FakeElement[];
  pages: FakeElement[];
  body: FakeElement;
  location: { hash: string; search: string; readonly href: string };
  document: { title: string };
  // The fragments that `history.replaceState` got, in sequence.
  written: string[];
  // The addresses that `window.open` got, and the windows that it gave.
  opened: { url: string; name: string; window: FakeWindow }[];
  // The functions that `setInterval` got. The test calls them.
  timers: (() => void)[];
  // Give one key to `main.ts`. The result tells if `main.ts` stopped the
  // default operation of the browser.
  press: (key: string | Key) => boolean;
  // Give one click to `main.ts`.
  click: (click: number | Click) => void;
  // Give a movement of one finger from `start` to `end` to `main.ts`.
  swipe: (start: Point, end: Point) => void;
  // The text of the selection of the page.
  selection: string;
  // True while the document is in full screen.
  fullscreen: boolean;
  // True when the browser refuses full screen.
  refuses: boolean;
  // Type a fragment into the address bar.
  navigate: (hash: string) => void;
  // Send a message from a window to the page.
  receive: (data: unknown, source: FakeWindow | null) => void;
  element: (id: string) => FakeElement | undefined;
};

export function fakeWindow(): FakeWindow {
  const window: FakeWindow = {
    closed: false,
    received: [],
    postMessage: (data) => {
      window.received.push(data);
    },
  };
  return window;
}

export function element(
  id: string,
  className = "",
  dataset: Record<string, string | undefined> = {},
): FakeElement {
  const self: FakeElement = {
    id,
    className,
    dataset,
    style: {
      display: "none",
      properties: {},
      setProperty: (name, value) => {
        self.style.properties[name] = value;
      },
    },
    textContent: "",
    children: [],
    appendChild: (child) => {
      self.children.push(child);
    },
    replaceChildren: () => {
      self.children = [];
    },
    querySelector: (selector) =>
      self.children.find((child) => `.${child.className}` === selector) ?? null,
  };
  return self;
}

export function fakePage(maxSteps: number[], options: Options = {}): FakePage {
  const slides = maxSteps.map((max, index) =>
    element(`slide-${index + 1}`, "slide", { maxStep: String(max) }),
  );
  const handout = element("", "handout");
  maxSteps.forEach((max, index) => {
    for (let step = 1; step <= max; step++) {
      const page = element("", "handout-page", {
        slide: String(index + 1),
        step: String(step),
      });
      const notes = options.notes?.[index];
      if (notes !== undefined) {
        const aside = element("", "notes");
        aside.textContent = notes;
        page.appendChild(aside);
      }
      handout.appendChild(page);
    }
  });
  const pages = [...handout.children];
  const body = element("", "");
  if (options.progress !== undefined) {
    body.dataset.progress = options.progress;
  }
  if (options.duration !== undefined) {
    body.dataset.duration = options.duration;
  }
  // The renderer writes the progress bar into each document.
  const progress = element("progress");
  const all = () => [
    ...slides,
    handout,
    ...handout.children,
    progress,
    ...body.children,
  ];

  const listeners: Record<string, (event: unknown) => void> = {};
  const listen = (name: string, listener: (event: unknown) => void) => {
    listeners[name] = listener;
  };
  const call = (name: string, event: unknown) => {
    const listener = listeners[name];
    assert.ok(listener, `main.ts registered no function for ${name}`);
    listener(event);
  };

  const location = {
    hash: options.hash ?? "",
    search: options.search ?? "",
    get href() {
      return `file:///deck.html${this.search}${this.hash}`;
    },
  };
  const doc = {
    title: "Deck",
    body,
    getElementsByClassName: (name: string) =>
      all().filter((each) => each.className === name),
    getElementById: (id: string) =>
      all().find((each) => each.id === id) ?? null,
    createElement: () => element(""),
    addEventListener: listen,
    get fullscreenElement() {
      return page.fullscreen ? doc.documentElement : null;
    },
    get fullscreenEnabled() {
      return !page.refuses;
    },
    documentElement: {
      requestFullscreen: async () => {
        page.fullscreen = true;
      },
    },
    exitFullscreen: async () => {
      page.fullscreen = false;
    },
  };

  const touch = (point: Point) => ({ clientX: point.x, clientY: point.y });

  const page: FakePage = {
    slides,
    pages,
    body: doc.body,
    location,
    document: doc,
    written: [],
    opened: [],
    timers: [],
    press: (key) => {
      let stopped = false;
      const event = typeof key === "string" ? { key } : key;
      call("keydown", { ...event, preventDefault: () => (stopped = true) });
      return stopped;
    },
    click: (click) => {
      const event = typeof click === "number" ? { clientX: click } : click;
      const target = {
        closest: (selector: string) => {
          if (event.on !== undefined && selector.includes(".handout-page")) {
            return event.on;
          }
          return event.inside !== undefined && selector.includes(event.inside)
            ? {}
            : null;
        },
      };
      call("click", { button: 0, ...event, target });
    },
    swipe: (start, end) => {
      call("touchstart", { touches: [touch(start)] });
      call("touchend", { touches: [], changedTouches: [touch(end)] });
    },
    selection: "",
    fullscreen: false,
    refuses: false,
    navigate: (hash) => {
      location.hash = hash;
      call("hashchange", {});
    },
    receive: (data, source) => {
      call("message", { data, source });
    },
    element: (id) => all().find((each) => each.id === id),
  };

  const global = globalThis as unknown as Record<string, unknown>;
  global.document = doc;
  global.window = {
    addEventListener: listen,
    innerWidth: 1200,
    getSelection: () => ({ isCollapsed: page.selection === "" }),
    opener: options.opener ?? null,
    open: (url: string, name: string) => {
      const window = fakeWindow();
      page.opened.push({ url, name, window });
      return window;
    },
  };
  global.location = location;
  global.history = {
    replaceState: (_data: unknown, _unused: string, url: string) => {
      page.written.push(url);
      location.hash = url;
    },
  };
  global.setInterval = (callback: () => void) => {
    page.timers.push(callback);
    return 0;
  };
  return page;
}

// The last message that a fake window got.
export function last(window: FakeWindow): unknown {
  return window.received[window.received.length - 1];
}

// The last message that a fake window got, with no time. The time comes from
// the clock, so a test reads the position and the black screen only, and it
// makes sure that the time is a number.
export function lastPosition(window: FakeWindow): unknown {
  const message = last(window) as Record<string, unknown>;
  const { time, ...position } = message;
  assert.equal(typeof time, "number", "a message with no time");
  return position;
}
