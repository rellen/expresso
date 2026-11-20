# The size of a slide

A slide fills the window of the browser, and its text has a size of 48 pixels for 1rem. In a
window that is smaller than 1280 by 720 pixels, the text becomes smaller with the window. Thus
a slide always has 26.67rem by 15rem or more.

## The font size

The `html` element has this rule on a screen:

```css
font-size: min(48px, 100vw * 48 / 1280, 100svh * 48 / 720);
```

A browser that does not know `svh` uses `100vh` in its place.

| Window | Font size of the `html` element | Size of a slide in rem |
| --- | --- | --- |
| 1920 by 1080 pixels | 48 px | 40 by 22.5 |
| 1280 by 720 pixels | 48 px | 26.67 by 15 |
| 1024 by 768 pixels | 38.4 px | 26.67 by 20 |
| 1200 by 630 pixels, the card of `--card` | 42 px | 28.57 by 15 |
| 844 by 390 pixels, a phone in the landscape direction | 26 px | 32.46 by 15 |
| 390 by 844 pixels, a phone in the portrait direction | 14.6 px | 26.67 by 57.7 |

- A window of 1280 by 720 pixels or larger gives a slide more room, and the text keeps its
  size.
- A smaller window shows the slide of a window that is 1280 pixels wide, or 720 pixels high, at
  a smaller scale. Each line of a text keeps its words.
- A slide fills the window in each proportion. A phone in the portrait direction shows a
  tall slide. This is the intended layout: the slide does not turn, and it does not show
  16:9 with an empty area above and below it.

## The height of the window

The height of the window is `100svh`, the small viewport height. A browser of a phone shows
bars, such as the address bar, and it can hide them. `100svh` is the height while the bars
show, so the bars do not cover the bottom of the slide, the footer or the progress bar.

- The slide does not change its size when the bars go. A strip of the background can then
  show under the slide.
- Each rule of the style sheet with the height of the window uses `svh` on a screen. Paper
  has no bars, so the rules of paper keep `vh`.
- `vh` and `vw` in the `css` option of a deck keep their meaning. Use `svh` for a height
  that must not go under the bars.

## The lengths of a deck

| Length | In a window smaller than 1280 by 720 pixels |
| --- | --- |
| `rem` and `em`, such as `"4rem"` | It becomes smaller with the text. |
| One number of pixels, such as `width "300px"` or `set: [x: "-200px"]` | It becomes smaller with the text. The document holds `calc(300 * var(--px))`. |
| A percentage of a `width` option, such as `"60%"` | It is a part of the window's width. |
| `vw` and `vh` | They are parts of the window. |
| A value with more than one number, such as `"calc(50% + 10px)"` | The pixels keep their size. |
| A length in pixels in [the css option](css-option.md) | It keeps its size. Use `rem`. |
| A length in pixels for a part of a formula, such as `set: [x: "40px"]` | It becomes smaller with the text. In a window of 640 by 360 pixels, the part moves by 20 pixels. |
| A length in pixels for a part of a diagram | It keeps its size. A pixel for a part of a diagram is a unit of its SVG file, and the diagram becomes smaller with the slide. |

In a window of 1280 by 720 pixels or larger, a length in pixels is that number of pixels.

## The parts of the presenter

These parts of the presenter are not a slide:

- the menu,
- the button of the menu,
- the list of keys,
- the speaker view,
- the table of the times,
- the report of the layout check.

Their text keeps its size in each window. On a touch screen, the button of the menu is in the
top right corner of the present view. See
[The button of the menu](presenter.md#the-button-of-the-menu).

## The viewport tag

Each document has this tag:

```html
<meta name="viewport" content="width=device-width, initial-scale=1"/>
```

A phone then gives the document the width of its screen. The tag has no limit of the
zoom, so the user can make the page larger.

## Paper

Paper does not follow this rule. The handout has a font size of 32 pixels for 1rem, and
the export with one page for each slide has 48 pixels. See
[The export options](export-options.md).

`docs/small-windows.md` in the repository gives the design. To find a slide that does not
fit a small window, see [Check the layout](../how-to/check-the-layout.md).
