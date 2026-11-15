# A slide in a small window

This document gives the design for a slide in a window that is smaller than 1280 by 720
pixels, such as the screen of a phone, and for the viewport tag of the document. Issue
#590 asked for it. The code contains this design. The document records ten decisions, and
each is settled. Its last section, "The result", tells what changed during the work.

## The problem

The text of a slide had a fixed size: the `html` element had `font-size: 48px` in each
window. A slide thus needed a window of a sufficient width.

- The document had no `meta name="viewport"`. A phone then gave the document a width of
  980 pixels and showed it at a scale of 0.4. Lighthouse 13.6 gave the insight `viewport`
  the score 0.5.
- With the usual tag, `width=device-width, initial-scale=1`, a phone gave the document its
  own width of 390 pixels, and the browser cut each heading at the right edge.
  `docs/document-tags.md` records that test.
- A small window on a computer cut a slide in the same way. `--check=layout` at 390 by 844
  and at 844 by 390 pixels gave 20 problems for `examples/dsl_deck.exs`.

## The plan

1. The font size of the `html` element becomes smaller with a small window. Each size of a
   slide is in `rem`, so the slide becomes smaller as a whole.
2. The parts of the presenter that are not a slide keep their size.
3. A length that a deck gives in pixels becomes smaller with the slide.
4. The document gets the viewport tag.

## The decisions

Each decision is settled.

1. **The text of a slide becomes smaller, and the slide is not a picture at a scale.** The
   alternative was a slide of a fixed size with the `zoom` property. That alternative
   needs a script for the scale, because CSS cannot divide the width of the window by a
   length in each browser. It also changes the coordinates of the laser pointer, of the
   drawing, of the zoom and of the morph in each window. A smaller font size changes only
   a small window, and it needs no script.
2. **The limit is a window of 1280 by 720 pixels.** The rule is
   `font-size: min(48px, 100vw * 48 / 1280, 100vh * 48 / 720)`. A window of that size or
   larger gives 48 pixels, as before, so a deck on a projector does not change. A slide
   has 26.67rem by 15rem or more in each window. 1280 by 720 is the size of the browser
   tests, and it is a usual size of a small projector.
3. **The width and the height are limits.** A phone in the landscape direction has a
   sufficient width and a small height. Without the limit of the height, a slide had 8rem
   of height there.
4. **A slide fills the window, as before.** A phone in the portrait direction shows a tall
   slide, and not a slide of 16:9 with an empty area. A slide is a column with a flexible
   height in each window, and a window of 4:3 on a projector uses the same rule.
5. **The line breaks are those of a window of 1280 pixels.** In a window with less width,
   each line has the same words as in a window of 1280 pixels, because the text and the
   width become smaller together.
6. **The parts of the presenter keep their size.** The menu, the list of keys, the speaker
   view, the table of the times, the typed slide number and the report of the layout
   check are not a slide. Their rules use the custom property `--ui`, which is 48 pixels
   in each window, in place of `rem`. Without this, a window of 960 by 600 pixels gave the
   menu a text of 10.8 pixels, and not 14.4.
7. **A length of the deck in pixels follows the scale.** A deck gives lengths such as
   `width "300px"` and `set: [x: "-200px"]`. The renderer writes one number of pixels as
   that number of the custom property `--px`, which is `calc(1rem / 48)`. The length is
   then the same as before in a window of 1280 by 720 pixels or larger, and it becomes
   smaller with the text in a small window.
8. **A part and a copy keep their pixels.** A pixel of a part of a diagram is a unit of
   its SVG file, and the browser already draws the file at the scale of the slide.
   `move_to` writes such a distance.
9. **The viewport tag is `width=device-width, initial-scale=1`.** It has no
   `maximum-scale` and no `user-scalable`, so the user can still zoom the page, as
   criterion 1.4.4 of WCAG asks.
10. **Paper does not change.** The rules of paper give the `html` element 32 pixels, or 48
    pixels for the export of one page for each slide. They come after the rule of the
    screen.

## The answers to the questions of the issue

1. **Does a slide keep its line breaks in each window?** Yes, for a window with less width
   than 1280 pixels. See decision 5.
2. **Does a phone in the portrait direction show a slide of 16:9?** No. See decision 4.
3. **Does the presenter script need a change for a tap and for a swipe?** No. A browser
   test taps a phone of 390 by 844 pixels, and the deck goes to the next step.

## The result

The code follows the plan, with these changes:

1. **The drawing layer has its box in the style sheet.** The element `drawing` had no
   size until the presenter script put it on the box of the slide. With the viewport tag,
   Lighthouse counted that change as a layout shift of 1, and the performance score went
   from 100 to 75. The layer now has the box of the window from the first paint.
2. **`Expresso.Element.slide_pixels/1` and `slide_length/1` write a length.** Each element
   with a `width` option calls `slide_length/1`: an image, a diagram, a chart, a tree, a
   QR code, an embed and a video. `Expresso.Overlay.Render` calls `slide_pixels/1` for
   each value of `set`, and a column calls it for its width.
3. **Only one number of pixels changes.** A value such as `calc(50% + 10px)` goes into the
   document as it is, and so does a rule of the `css` option.

These are the measurements after the change:

| Measurement | Before | After |
| --- | --- | --- |
| `--check=layout` of `examples/dsl_deck.exs` at 390 by 844, 844 by 390 and 1280 by 720 | 20 problems | 1 problem: the text of a diagram is small. |
| The font size of the `html` element at 390 by 844 | 48 px | 14.6 px |
| The font size of the `html` element at 844 by 390 | 48 px | 26 px |
| The font size of the `html` element at 1280 by 720 and at 1920 by 1080 | 48 px | 48 px |
| The text of a step row of the menu at 390 by 844 | 14.4 px | 14.4 px |
| Lighthouse 13.6, `examples/animations/chart.exs`: the insight `viewport` | 0.5 | 1 |
| The same deck: Cumulative Layout Shift, and performance | 0, and 100 | 0, and 100 |
| Lighthouse 13.6, `examples/dsl_deck.exs`: performance | 84 | 84 |

Each of the 434 browser tests from before the change passed with no change to a test.
They use a window of 1280 by 720 pixels or larger, where a slide does not change.

## The limits

- A length in pixels in the `css` option of a deck does not follow the scale. Use `rem`
  for a size that must become smaller with the slide.
- A length in pixels of a part of a formula does not follow the scale, because a part of
  a formula and a part of a diagram are the same entity.
- A value with more than one number, such as `calc(50% + 10px)`, keeps its pixels.
- The height of the window is `100vh`. A browser of a phone can cover the bottom of the
  slide with its bar, until the user moves the page.
- The text of a diagram from an SVG file can be small on a phone, because the file gives
  its size. `--check=layout` reports it.
- The handout view becomes smaller with the slide in a small window.
- Nobody examined the document on a phone. The tests use the emulation of Chromium.
