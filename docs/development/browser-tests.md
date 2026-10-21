# The browser tests

The tests of `test/e2e/` render a deck to an HTML file, open the file in Chromium, and
operate the presenter as a user does. They press keys, click, tap, swipe, read computed
styles, reload the page, open the speaker view in a second window, and count the pages of a
PDF. Playwright has no swipe, so a script in the page sends the touch events. They find the
defects that the unit tests of `assets/test/` cannot find, because those tests use no CSS
and no browser.

```sh
mix test --only e2e
```

`mix test` excludes these tests, because they need Node, the Playwright driver and a
browser. A test renders each example deck, and two of them draw a graph, so the browser
tests also need Graphviz and D2. `graph-tools.md` tells how to install them. `playwright_ex` is the Elixir client, and it starts the driver of
`node_modules/playwright`, which `package.json` pins. `Expresso.E2E` in `test/support/`
is the case template. It starts one browser for each module and a new context for each
test, and it gives the helpers, such as `press/2`, `position/1`, `pause_animations/3` and
`pdf_pages/1`.

With motion, a key press can return before the presenter shows the change. The presenter
changes the slide inside `document.startViewTransition`, and the browser runs that update
later. On a slow computer, the update can come more than a second later. An example is a
run of `mix check` that builds the release at the same time. The browser can also stop for
some seconds while a change runs. Therefore a test with motion waits for a condition, and
not for a time:

- Wait for the slide with `wait_for_position/2`. Wait for a text with `wait_for_texts/3` or
  `wait_for/2`, because the presenter writes the number of a count at the next frame.
- To read a change before its end, give each change a long duration with `slow_motion/2`.
  Then pause the change at a known time with `pause_animations/3`, read the page, and move
  the change to its end with `finish_animations/2`.
- Pause a change at a time that is not its middle. At the middle, a symmetric easing, such
  as `ease-in-out`, gives the same value as `linear`. The test then cannot find an easing
  that is not correct.
- Do not read a value after `Process.sleep/1`. The stat count test, the sunburst growth test
  and the line segment test did so, and they failed on a slow computer.

The variable `EXPRESSO_CHROMIUM` gives the path of a Chromium executable. A remote session
has no browser at the path of Playwright, so the hook sets the variable to the Chromium
of the container. Without the variable, Playwright uses its own browser:

```sh
npx playwright install --only-shell chromium
```

The workflow runs the same command in `.github/actions/setup-playwright`, and a cache
keeps the browser from one run to the next. The runner image already has each system
library of the headless browser, so the workflow does not use `--with-deps`.

## Look at a deck

Make an HTML document, and then open it. `examples/demo.exs` uses the functions, and
`examples/dsl_deck.exs` uses the DSL:

```sh
mix expresso examples/demo.exs /tmp/demo.html
mix expresso examples/dsl_deck.exs /tmp/dsl.html
```

`examples/line4/line4.exs` is a full talk about an isometric factory in one HTML file. It
is a copy of `talks/line-4/deck.exs` of
[iso-factories](https://github.com/rellen/iso-factories), and its header tells how the two
differ. It uses many features of Expresso: a deck template, a theme from a map, the `css`
option, sections and a toc, the stat, callout, icon, chart, code, diagram, table, image,
video, embed and QR code elements, and the overlay options. Its files are in the same
directory, with `line-4.html`, a copy of the factory page. Use it to look at a change to the
style sheet on real slides:

```sh
mix expresso examples/line4/line4.exs /tmp/line4.html
```

With `--watch`, the task renders the deck again after each change, and the page reloads.
Open `http://127.0.0.1:4100/`:

```sh
mix expresso examples/dsl_deck.exs --watch
```

The browser tests cover the behavior of the presenter. Add a test to `test/e2e/` for a
new behavior. A look at the slides is still necessary after a change to
`assets/style.css`. `?check` in the address finds an element past an edge of the window,
a line of code that breaks, and small text in a chart or a diagram. `test/e2e/layout_check_test.exs` runs it on
`examples/line4/line4.exs` at 1920 × 1080, and on each example deck of the GIFs at
1280 × 720. `mix expresso deck.exs --check=a11y` runs the layout check and axe-core on a
deck with no window, and `test/e2e/check_test.exs` tests it. The checks do not see an
order or a size that is wrong, so look at the slides too. A remote container has no display,
but it has Chromium, and `npm install` gives Playwright. The browser is at
`/opt/pw-browsers/chromium`. This path is not the default path of Playwright, so give it
to `chromium.launch`.

```js
import { chromium } from "playwright";

const browser = await chromium.launch({
  executablePath: "/opt/pw-browsers/chromium",
});
const page = await browser.newPage({ viewport: { width: 1000, height: 620 } });
await page.goto("file:///tmp/demo.html");

// Make sure that the result comes from the standards mode. In the quirks mode
// a percentage height gives a different layout, and the defect is not visible.
console.log(await page.evaluate(() => document.compatMode)); // "CSS1Compat"

// The presenter reads the keys j, k and p.
await page.keyboard.press("j");

// Read the computed style, because an error in a style attribute is silent.
const visible = await page.$$eval("section.slide", (elements) =>
  elements
    .filter((element) => getComputedStyle(element).display !== "none")
    .map((element) => element.id),
);
console.log(visible);

await page.screenshot({ path: "/tmp/slide.png" });
await browser.close();
```

Look at these cases after a change to the theme or to the presenter:

- A deck with no slide. Each key must give no error in the console.
- A word that is longer than the slide. The document must not become wider than the
  screen, and `document.documentElement.scrollWidth` gives that answer.
- A heading of many words, and a slide of many elements.
- A screen of 1440, 1024, 800 and 500 pixels.
- The print view, with `page.emulateMedia({ media: "print" })`, on A4 and on letter.

The theme gives `html` a font size of 48 pixels, and that size does not change with the
screen. Therefore the content of a slide can be taller than the slide on a screen of 800
pixels or less. A theme with a font size in a viewport unit does not have this limit, and
that change alters each deck.

Read the computed style, and do not read the attribute. A defect in a style attribute gives
no error. The browser drops the declaration, and the page looks almost correct.
