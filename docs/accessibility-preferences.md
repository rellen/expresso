# The color preferences of a user, and the new criteria of WCAG 2.2

This document records an investigation of a deck in forced colors, with the preference
for more contrast, and against three criteria that WCAG 2.2 added. Issue #571 asked for
it. The document gives the state on 2026-11-15, a proposal for each defect, and two
questions for the maintainer. No code changed.

## The method

The browser was Chromium 159 (headless shell), with a window of 1280 by 720 pixels.
Playwright gave the browser the preference with the context option `forcedColors`, and
the color scheme `light` or `dark`. In forced colors with the light scheme, the canvas is
white and the text is black. With the dark scheme, the canvas is black and the text is
white.

The investigation used 24 decks:

- `examples/dsl_deck.exs` and `examples/demo.exs`,
- 18 decks of `examples/animations/`: a callout, five charts, two decks with code, the dim
  state, a footnote, an icon, a stat, a tree, the typewriter effect, a background, a QR
  code, a formula and a video,
- three decks with a diagram: one from an SVG file, one from Graphviz and one from
  Mermaid,
- `chart.exs` with the theme `:dracula`.

The numbers of the tables come from the first 20 decks, unless a row names a different
deck.

A script went through each step of each deck in three modes. It read the color of each
text and of each SVG shape, and it calculated the contrast with the background behind the
element. It made a picture of the first 12 steps of each deck in each mode. A second
script looked at the parts that the presenter script draws, and a third script measured
each control of each view.

The method has these limits:

- The browser gives only a white canvas or a black canvas. A high contrast theme of
  Windows can have different colors, such as yellow on black.
- Nobody used a screen reader. The session has no NVDA and no VoiceOver.
- The script measures a text inside an SVG shape against the slide, and not against the
  shape. The pictures gave the answer for such a text.
- Firefox and Safari are not in the investigation.

## Forced colors

### What the browser changes

In forced colors, the browser replaces the color, the background color, the border color
and the outline color of each HTML element with a color of the system. It removes each
`box-shadow`, each `text-shadow` and each gradient of a background. It does not change the
`fill` and the `stroke` of an SVG element, and it does not change an image.

`assets/style.css` has no rule for forced colors, so a deck gets these changes with no
correction.

### What stays correct

| Part | Result |
| --- | --- |
| The text of a slide | Each of the 921 HTML texts has 21:1, in the two schemes. |
| A callout | The kind color and the tint go away. The icon and the title still tell the kind. |
| The `alert` state | Its outline uses `currentColor`, so it shows. |
| The selected step of the menu | It keeps its outline and its bold text. |
| The selected slide of the overview | It keeps its outline. |
| A tree, a stat, a footnote, an icon | Each text and each line shows. |
| A QR code | It keeps its black modules on its white square. |

### The defects

| Number | Part | What happens | Measurement |
| --- | --- | --- | --- |
| F1 | The text of a chart | The names of the series and the values do not show when the canvas has the tone of the text of the theme. The labels of the axes are weak. | Light theme, dark scheme: 127 of 1056 texts are under the minimum. 73 have 1:1 and 54 have 3:1, and each one is a text of a chart. Theme `:dracula`, light scheme: 19 of the 35 texts of the chart are under the minimum, with 1.07:1 or 1.97:1. |
| F2 | A diagram of Mermaid | The arrow from `Test` to `Release` is black on the black canvas, so its part outside the group does not show. The label `CI` of the group is weak. | `mermaid_flowchart.exs`, dark scheme, from the picture. The diagram from an SVG file and the diagram of Graphviz had no defect. |
| F3 | The progress bar | It does not show. | Its background color is `rgb(0, 0, 0)` on the canvas `rgb(0, 0, 0)`. In the usual mode it is `rgb(52, 101, 164)`. |
| F4 | The laser pointer | It does not show. | Its background color is the canvas color, and its `box-shadow` is `none`. |
| F5 | The pen of the drawing | The line is weak on a black canvas. | `rgb(164, 0, 0)` has 2.6:1 on black. On white it has 8.1:1. |
| F6 | The dim state | A dimmed element looks the same as the current element. | `dim_contrast.exs`, step 2: 9 different text colors in the usual mode, and 1 in forced colors. |
| F7 | A color with a meaning | The colors of code go away, and so does the color of a part of a formula. | `code_config.exs`: 11 text colors become 1. `math_parts.exs`: 3 become 1. |
| F8 | The background of a slide | A gradient goes away. The text stays readable, because the browser sets the two colors. | `background.exs`: 1 element with a background image becomes 0. |

F1 and F2 have the same cause: the browser does not change the `fill` or the `stroke` of
an SVG element. A chart and a diagram keep the text color of the theme, and the canvas
takes the color of the system.

F3 and F4 have the same cause: the part is a box with only a background color.

The rule that removes the `box-shadow` of the laser pointer also applies to the
underline of the `highlight` state and to the cursor of the typewriter effect. The
investigation did not measure these two.

### The alternatives for the content of a slide

| Alternative | Effect | Cost |
| --- | --- | --- |
| A. The slide keeps its colors, with `forced-color-adjust: none` on each slide. | F1, F2, F6, F7 and F8 go away, because the slide shows as its author made it. Each built-in theme has the contrast minimums of WCAG. | The user does not get the colors that the user selected. |
| B. Each part takes the colors of the system. | The user gets the colors of the system in each part. | A chart, a diagram and a formula need a rule for each kind. A diagram from a file of the user cannot get a rule. The dim state needs a mark that is not a color. |
| C. The text takes the colors of the system, and each graphic keeps its colors on a plate with the background color of the theme. | The text obeys the user. A chart, a diagram, a formula with colors and an image show as their author made them, as a photograph does. | F6 and F7 for code still need a mark that is not a color. |

The proposal is alternative C. It is the usual rule for a picture in forced colors, and it
does not need a rule for each kind of chart.

F3, F4 and F5 do not depend on the alternative. The progress bar, the laser pointer and
the pen are parts of the presenter. They can use a color of the system, such as
`Highlight` or `CanvasText`.

**Question 1 for the maintainer:** alternative A, B or C?

## The preference for more contrast

`assets/style.css` has no rule for `prefers-contrast: more`, so the preference changes
nothing.

These are the contrasts of the roles with the background of the theme:

| Role | Default theme | `:dracula` | Minimum for more contrast (WCAG level AAA) |
| --- | --- | --- | --- |
| `--text` | 21:1 | 13.4:1 | 7:1 |
| `--muted` | 7.0:1 | 7.2:1 | 7:1 |
| `--accent` | 5.9:1 | 7.2:1 | 7:1 |
| `--text-dim`, with the default `dim_contrast` of 3 | 3.4:1 | 4.0:1 | 7:1 |
| `--code-text-dim` | 3.5:1 | 3.7:1 | 7:1 |

The text and the muted text have the minimum. The accent of the default theme and the
dimmed roles do not.

The proposal has three parts:

1. For `prefers-contrast: more`, the document gives the dimmed roles the values of
   `dim_contrast 7`. The renderer calculates the dimmed roles for each deck, so it must
   write a second set of values in a media query.
2. A text with the accent color takes the text color.
3. The outline of the focus and of a selected element becomes 3 pixels wide.

**Question 2 for the maintainer:** is this proposal correct, or does the preference stay
with no effect?

## The new criteria of WCAG 2.2

| Criterion | Result | Measurement |
| --- | --- | --- |
| 2.4.11 Focus Not Obscured (Minimum) | No defect found. | The Tab key went through the present view, the menu, the list of keys, the overview, the handout view, the speaker view and the dialog of the times. No element covered a control with the focus. |
| 2.5.7 Dragging Movements | No defect found. | The script reads a drag for the drawing only, where the drag is the function. A swipe has a key and a tap as alternatives. The laser pointer and the zoom use no drag. |
| 2.5.8 Target Size (Minimum) | Two controls are 1 pixel too low. | A step row of the menu is 521 by 23 pixels: 10 of the 14 options of `dsl_deck.exs`. The search field of the list of keys is 778 by 23 pixels. The minimum is 24 by 24. |

The sizes come from a window of 1280 by 720 pixels. The font size of the document depends
on the window, so a smaller window gives smaller controls. The proposal is a minimum
height of 24 pixels for the two controls.

The present view, the overview, the handout view and the speaker view have no control
that takes the focus. The presenter script reads each key from the document.

The investigation also found two facts that are not new criteria of WCAG 2.2:

- The search field of the list of keys has no outline when it has the focus. It shows
  only its text cursor.
- A slide of the overview is not an element that the Tab key reaches. The arrow keys
  select a slide.

## What the investigation did not do

- A pass with a screen reader.
- A test with a high contrast theme of Windows, with Firefox or with Safari.
- A measurement of the `highlight` state, of the cursor of the typewriter effect, and of
  the bar that marks the code line in focus.
- A test of each element. The 24 decks have no `embed`, no `audio`, no table and no
  speaker notes in forced colors.

## The plan for the tests

The browser tests can keep the state known:

1. `Expresso.E2E` gets a helper that opens a page with forced colors. The Playwright
   driver takes the option `forcedColors` for a context.
2. A test for each corrected defect: the text of a chart has 4.5:1 or more in the two
   schemes, the progress bar and the laser pointer do not have the canvas color, and a
   dimmed element is different from the current element.
3. A test for the two controls of criterion 2.5.8 at the window size of the tests.

## The issues

The investigation gives four issues. Two of them wait for an answer to a question:

| Issue | Defects | Waits for |
| --- | --- | --- |
| Show the progress bar, the laser pointer and the pen in forced colors | F3, F4, F5 | Nothing. |
| Give the step rows of the menu and the search field a height of 24 pixels | Criterion 2.5.8 | Nothing. |
| Make the content of a slide readable in forced colors | F1, F2, F6, F7, F8 | Question 1. |
| Give more contrast for `prefers-contrast: more` | The table of the roles | Question 2. |
