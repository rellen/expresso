// A fake page for the tests of `main.ts`. Node has no DOM, so this module puts
// a fake `document`, `window`, `location`, `history` and `setInterval` on the
// global object.
//
// `main.ts` runs when the module loads, and it reads the page one time.
// Therefore a test file calls `fakePage` in front of the import of `main.ts`.
// Node runs each test file in its own process, so each file gets one page.

import assert from "node:assert/strict";
import type { Kind } from "../src/deck.ts";
import { key, raw, texts } from "./fixtures.ts";

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
  hidden: boolean;
  children: FakeElement[];
  appendChild: (child: FakeElement) => void;
  replaceChildren: () => void;
  querySelector: (selector: string) => FakeElement | null;
  // The attributes `data-*` of the element, in its `dataset`.
  setAttribute: (name: string, value: string) => void;
  getAttribute: (name: string) => string | null;
  removeAttribute: (name: string) => void;
};

// The key in `dataset` of an attribute `data-*`, such as `speakerNext` for
// `data-speaker-next`.
function datasetKey(name: string): string {
  assert.ok(name.startsWith("data-"), `the fake page has no attribute ${name}`);
  return name
    .slice("data-".length)
    .replace(/-([a-z])/g, (_all, letter: string) => letter.toUpperCase());
}

// The `body` of a fake document.
export type FakeBody = FakeElement;
export const fakeBody = (): FakeBody => element("", "");

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
  // The element that has the focus, such as a field of text.
  target?: unknown;
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
  // The link of the `goto` option under the click. It holds its commands in
  // `data-commands`.
  link?: FakeElement;
  // An element of the HTML of a deck with `data-commands`, which the renderer
  // did not write. Only the selector `[data-commands]` finds it.
  stray?: FakeElement;
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
  // The value of `data-progress` that the renderer writes on the `body`. The
  // value `"false"` also gives the program the first state with no progress
  // bar.
  progress?: string;
  // The `duration` option of the deck, in minutes.
  duration?: number;
  // The kind of the transition of each slide, in slide order. A slide without
  // an entry fades.
  transitions?: Kind[];
  // True for a browser with the View Transitions API.
  viewTransitions?: boolean;
  // True for a document with a light and a dark variant of its theme.
  variants?: boolean;
  // True for a screen that asks for a dark scheme.
  dark?: boolean;
};

export type FakePage = {
  slides: FakeElement[];
  pages: FakeElement[];
  body: FakeElement;
  location: { hash: string; search: string; readonly href: string };
  document: {
    title: string;
    documentElement: { dataset: Record<string, string | undefined> };
  };
  // The fragments that `history.replaceState` got, in sequence.
  written: string[];
  // The addresses that `window.open` got, and the windows that it gave.
  opened: { url: string; name: string; window: FakeWindow }[];
  // The functions that `setInterval` got. The test calls them.
  timers: (() => void)[];
  // Give one key to `main.ts`. The result tells if `main.ts` stopped the
  // default operation of the browser.
  press: (key: string | Key) => boolean;
  // Give one click to `main.ts`. The result tells if `main.ts` stopped the
  // default operation of the browser, such as the address of a link.
  click: (click: number | Click) => boolean;
  // Give a movement of one finger from `start` to `end` to `main.ts`.
  swipe: (start: Point, end: Point) => void;
  // The text of the selection of the page.
  selection: string;
  // True while the document is in full screen.
  fullscreen: boolean;
  // True when the browser refuses full screen.
  refuses: boolean;
  // The kind and the direction of each view transition, in sequence.
  transitions: string[];
  // True when the reader asks for reduced motion.
  reduced: boolean;
  // Type a fragment into the address bar.
  navigate: (hash: string) => void;
  // Send a message from a window to the page.
  receive: (data: unknown, source: FakeWindow | null) => void;
  element: (id: string) => FakeElement | undefined;
  // The rows of the list of keys that shows, as the names of the keys and the
  // text. The test fails when not exactly one list shows.
  keys: () => { names: string; text: string }[];
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
    hidden: false,
    children: [],
    appendChild: (child) => {
      self.children.push(child);
    },
    replaceChildren: () => {
      self.children = [];
    },
    querySelector: (selector) =>
      self.children.find((child) => `.${child.className}` === selector) ?? null,
    setAttribute: (name, value) => {
      self.dataset[datasetKey(name)] = value;
    },
    getAttribute: (name) => self.dataset[datasetKey(name)] ?? null,
    removeAttribute: (name) => {
      delete self.dataset[datasetKey(name)];
    },
  };
  return self;
}

export function fakePage(maxSteps: number[], options: Options = {}): FakePage {
  const slides = maxSteps.map((max, index) =>
    element(`slide-${index + 1}`, "slide", { maxStep: String(max) }),
  );
  // The list of the steps and the program that the renderer writes for the
  // deck. They come from the fixture file.
  const found = texts(key(maxSteps, options.transitions));
  const steps = JSON.parse(found.deck);
  steps.duration_ms =
    options.duration === undefined ? null : options.duration * 60_000;
  const list = element("expresso-deck");
  list.textContent = JSON.stringify(steps);
  const program = element("expresso-program");
  // The renderer writes the `progress` of the deck into the first state of the
  // program.
  const code = JSON.parse(found.program);
  code.state.progress = options.progress !== "false";
  program.textContent = JSON.stringify(code);
  // The renderer writes the list of keys as a `dialog` with a section for each
  // mode. The fake dialog and its sections have the parts that `dom.ts` and
  // `search.ts` use.
  const panels = raw.help.map(([mode, rows]) => {
    const panel = Object.assign(element("", "", { mode }), {
      open: false,
      toggleAttribute: (name: string, on: boolean) => {
        if (on) panel.setAttribute(name, "");
        else panel.removeAttribute(name);
      },
    });
    for (const [names, text] of rows) {
      const row = element("");
      const kbd = element("");
      kbd.textContent = names;
      const span = element("");
      span.textContent = text;
      row.appendChild(kbd);
      row.appendChild(span);
      panel.appendChild(row);
    }
    return panel;
  });
  const closers: (() => void)[] = [];
  const help = Object.assign(element("help"), {
    open: false,
    showModal: () => {
      help.open = true;
    },
    close: () => {
      help.open = false;
      for (const closer of closers) closer();
    },
    toggleAttribute: () => undefined,
    addEventListener: (name: string, listener: () => void) => {
      if (name === "close") closers.push(listener);
    },
    querySelector: () => null,
    querySelectorAll: (selector: string) =>
      selector === "details[data-mode]" ? panels : [],
  });
  for (const panel of panels) {
    help.appendChild(panel);
  }
  const handout = element("", "handout");
  let first = 0;
  maxSteps.forEach((max, index) => {
    for (let step = 1; step <= max; step++) {
      // The page of the last step of each slide holds the commands of a click
      // in the overview, as the renderer writes them.
      const commands =
        step === max
          ? JSON.stringify([
              ["goto_slide", index + 1],
              ["set", "overview", false],
            ])
          : undefined;
      // The renderer writes the index of the step in the list of the steps,
      // and marks the page of the last step of each slide.
      const page = element("", "handout-page", {
        slide: String(index + 1),
        step: String(step),
        index: String(first + step - 1),
        thumbnail: step === max ? "" : undefined,
        commands,
      });
      const notes = options.notes?.[index];
      if (notes !== undefined) {
        const aside = element("", "notes");
        aside.textContent = notes;
        page.appendChild(aside);
      }
      handout.appendChild(page);
    }
    first += max;
  });
  const pages = [...handout.children];
  // The renderer writes the four elements of the speaker view into the
  // handout view.
  for (const id of [
    "speaker-notes",
    "speaker-position",
    "speaker-timer",
    "speaker-left",
  ]) {
    handout.appendChild(element(id));
  }
  const body = element("", "");
  if (options.progress !== undefined) {
    body.dataset.progress = options.progress;
  }
  // The renderer writes the progress bar into each document.
  const progress = element("progress");
  const all = () => [
    list,
    program,
    help,
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
    // Only a selector of one class, with one attribute or none, such as
    // `.handout-page[data-thumbnail]`.
    querySelectorAll: (selector: string) => {
      const match = /^\.([\w-]+)(?:\[(data-[\w-]+)\])?$/.exec(selector);
      assert.ok(match, `the fake page has no selector ${selector}`);
      const [, className, attribute] = match;
      return all().filter(
        (each) =>
          each.className === className &&
          (attribute === undefined || each.getAttribute(attribute) !== null),
      );
    },
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
      dataset: {} as Record<string, string | undefined>,
      // The renderer writes `data-variants` for a theme with a light and a
      // dark variant.
      hasAttribute: (name: string) =>
        name === "data-variants" && options.variants === true,
      requestFullscreen: async () => {
        page.fullscreen = true;
      },
    },
    // The fake browser runs the update at once, and it keeps the kind and
    // the direction that the `html` element had at the start.
    startViewTransition: options.viewTransitions
      ? (update: () => void) => {
          const { transition, direction } = doc.documentElement.dataset;
          page.transitions.push(`${transition} ${direction}`);
          update();
        }
      : undefined,
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
      const event: Click =
        typeof click === "number" ? { clientX: click } : click;
      // A link of the `goto` option is an interactive element that holds
      // commands. A page of the overview holds commands, and it is not
      // interactive.
      const target = {
        closest: (selector: string) => {
          const link =
            event.link === undefined
              ? null
              : {
                  ...event.link,
                  matches: (each: string) => each === "a.goto[data-commands]",
                };
          // The selector of the two kinds of element that hold commands.
          if (selector.includes(".handout-page[data-commands]")) {
            return link ?? event.on ?? null;
          }
          if (selector === "[data-commands]") {
            return event.stray ?? null;
          }
          if (link !== null && selector.includes("a,")) {
            return link;
          }
          return event.inside !== undefined && selector.includes(event.inside)
            ? { matches: () => false }
            : null;
        },
      };
      let stopped = false;
      call("click", {
        button: 0,
        ...event,
        target,
        preventDefault: () => (stopped = true),
      });
      return stopped;
    },
    swipe: (start, end) => {
      call("touchstart", { touches: [touch(start)] });
      call("touchend", { touches: [], changedTouches: [touch(end)] });
    },
    selection: "",
    fullscreen: false,
    refuses: false,
    transitions: [],
    reduced: false,
    navigate: (hash) => {
      location.hash = hash;
      call("hashchange", {});
    },
    receive: (data, source) => {
      call("message", { data, source });
    },
    element: (id) => all().find((each) => each.id === id),
    keys: () => {
      assert.ok(help.open, "the list of keys is not open");
      const shown = panels.filter(
        (panel) => panel.dataset.current !== undefined,
      );
      assert.equal(shown.length, 1, "not exactly one list of keys is current");
      return (shown[0]?.children ?? []).map((row) => ({
        names: row.children[0]?.textContent ?? "",
        text: row.children[1]?.textContent ?? "",
      }));
    },
  };

  const global = globalThis as unknown as Record<string, unknown>;
  global.document = doc;
  global.window = {
    addEventListener: listen,
    innerWidth: 1200,
    getSelection: () => ({ isCollapsed: page.selection === "" }),
    matchMedia: (query: string) => ({
      matches:
        (query.includes("reduce") && page.reduced) ||
        (query.includes("dark") && options.dark === true),
    }),
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

// The last message that a fake window got, with the time 1. The time comes
// from the clock, so the function makes sure that the time is a number, and a
// test compares the message with `position` of `messages.ts`.
export function lastPosition(window: FakeWindow): unknown {
  const message = last(window) as Record<string, unknown>;
  assert.equal(typeof message["time"], "number", "a message with no time");
  return { ...message, time: 1 };
}
