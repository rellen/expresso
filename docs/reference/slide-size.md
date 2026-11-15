# The size of a slide

A slide fills the window of the browser, and its text has a size of 48 pixels for 1rem.
In a window that is smaller than 1280 by 720 pixels, the text becomes smaller with the
window, so a slide always has 26.67rem by 15rem or more.

## The font size

The `html` element has this rule on a screen:

```css
font-size: min(48px, 100vw * 48 / 1280, 100vh * 48 / 720);
```

| Window | Font size of the `html` element | Size of a slide in rem |
| --- | --- | --- |
| 1920 by 1080 pixels | 48 px | 40 by 22.5 |
| 1280 by 720 pixels | 48 px | 26.67 by 15 |
| 1024 by 768 pixels | 38.4 px | 26.67 by 20 |
| 844 by 390 pixels, a phone in the landscape direction | 26 px | 32.46 by 15 |
| 390 by 844 pixels, a phone in the portrait direction | 14.6 px | 26.67 by 57.7 |

- A window of 1280 by 720 pixels or larger gives a slide more room, and the text keeps its
  size.
- A smaller window shows the slide of a window of 1280 pixels wide, or of 720 pixels high,
  at a smaller scale. Each line of a text keeps its words.
- A slide fills the window in each proportion. A phone in the portrait direction shows a
  tall slide.

## The lengths of a deck

| Length | In a window smaller than 1280 by 720 pixels |
| --- | --- |
| `rem` and `em`, such as `"4rem"` | It becomes smaller with the text. |
| One number of pixels, such as `width "300px"` or `set: [x: "-200px"]` | It becomes smaller with the text. The document holds `calc(300 * var(--px))`. |
| A percentage of a `width` option, such as `"60%"` | It is a part of the width of the window. |
| `vw` and `vh` | They are parts of the window. |
| A value with more than one number, such as `"calc(50% + 10px)"` | The pixels keep their size. |
| A length in pixels in [the css option](css-option.md) | It keeps its size. Use `rem`. |
| A length in pixels of a part of a diagram or of a formula | It keeps its size. A pixel of a part of a diagram is a unit of its SVG file. |

In a window of 1280 by 720 pixels or larger, a length in pixels is that number of pixels.

## The parts of the presenter

The menu, the list of keys, the speaker view, the table of the times and the report of
the layout check are not a slide. Their text keeps its size in each window.

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
