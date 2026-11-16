# The accessibility of a deck

This page gives what the document of a deck tells a screen reader, and what the deck must
give. For the steps, see [Make a deck accessible](../how-to/make-a-deck-accessible.md).

## The landmarks

| Element | Role | Holds |
| --- | --- | --- |
| `main.views` | `main` | The present view, the handout view, the progress bar and the live region. |
| `nav#menu` | `navigation`, with the name "Slides and steps" | The menu. |
| `dialog#help` | `dialog`, with the title of the list | The list of keys. |
| `aside.notes` | `complementary`, with the name "Notes: " and the name of the page | The notes of a page of the handout view. The speaker view holds the notes of the current step as paragraphs and lists, with no live region. |

The `main` element takes no box, so the views keep their layout.

## The slides

Each slide of the present view and each page of the handout view is a `section` with these
attributes:

| Attribute | Value |
| --- | --- |
| `role` | `group` |
| `aria-roledescription` | `slide` |
| `aria-label` | The position and the name of the slide, such as `Slide 2 of 3: A restart`. A page of the handout view also gives its step when its slide has more than one, such as `Slide 2 of 3, step 1 of 2: A restart`. |

The name is the `heading` of the slide. Without a heading, it is the name of the slide.
Without both, the label has the position only.

### The heading of a slide

Each slide and each page holds an `h1`, so a screen reader that moves from heading to
heading reaches each slide.

| Slide | `h1` |
| --- | --- |
| The slide template writes an `h1`, such as from the `heading` option | That `h1`. |
| The slide template writes no `h1` | An `h1` with the class `slide-hidden-heading`, which the style sheet hides from the eye. Its text is the heading, the name, or the position of the slide, such as `Slide 4 of 9`. |
| The slide gives `sr_heading false` | No hidden `h1`. |

## The title

The `title` element holds the name of the deck. A deck with no name takes the heading of
its first slide with a heading, and a deck with no heading takes `Slides`.

## The live region

`div#announce` has the role `status`, so a screen reader reads each change of its text and
does not stop what it reads. The screen and paper do not show it.

| Move | Text |
| --- | --- |
| To a different slide | The name of the slide, with its step when it has more than one step, such as `Slide 2 of 3, step 1 of 2: A restart`. |
| To a different step of the same slide | The step, such as `Step 2 of 2`. |
| `o` opens the overview | The word "Overview" and the name of the selected slide, such as `Overview. Slide 1 of 3: The start`. |
| A different slide in the overview | The name of the selected slide with no step, such as `Slide 2 of 3: A restart`. Enter goes to step 1 of that slide. |
| The overview closes with no move | The name of the current slide and its step, as for a move to a different slide. |
| A key with no move | No new text. |

The region is empty at load.

## The menu

| Element | Role | State |
| --- | --- | --- |
| The list of the menu | `listbox`, with the name "Slides and steps" | `aria-activedescendant` is the id of the option of the cursor. The list takes the focus while the menu is open. |
| The steps of a slide | `group`, with the name of the slide | — |
| A step | `option`, with the id `menu-step-<index>` | `aria-selected="true"` on the option of the cursor, and `aria-current="step"` on the option of the current step. |

The name of an option is its text: the word "Step", which only a screen reader reads, the
number of the step and its label. The option of a slide with one step and no label takes
the name of the slide. The picture of each slide in the menu is `inert`, so a screen reader
and the `Tab` key skip it.

## The progress bar

`div#progress` has the role `progressbar` with the name "Progress". `aria-valuenow` is the
part of the deck before the current step, from 0 to 100, as the width of the bar shows it.

## The elements

| Element | What a screen reader gets |
| --- | --- |
| `image` | The `alt` option as the `alt` attribute. Without it, the image is decorative. |
| `diagram` | With the `alt` option, an `img` with that text as its name. Without it, the text of the SVG. A graph from Graphviz or D2 without `alt` gives a nested list of its nodes and edges, such as "web, to api", in the place of the text of the SVG. |
| `chart` | An `img` with the `title` option as its name, and a table of the values. |
| `stat` | The whole value as one text, such as "$4.2M", and the `label` option. |
| `icon` | Nothing for the drawing. The `label` option as text. |
| `qr_code` | An `img` with the `title` option, or the text of the code, as its name. |
| `video`, `audio`, `embed` | The `title` option as the name of the element. A video with the `captions` option has a `track` of captions. |
| `callout` | A `note`, with the header as text. |
| `math` | MathML, which a screen reader reads. A formula from the `tex` option is MathML too. A part of a later step, such as a line of a derivation with `reveal true`, is hidden until its step, as an element is. |
| `table` | The `caption` option as the name of the table. Each header cell is a `th` with a `scope`: `col` in the `header` row, and `row` for the first cell of a row with `row_header`. |
| An element of a later step | Nothing. The style sheet hides it with `visibility: hidden` until its step. |
| A part of a text of a later step | Nothing, as for an element. A part with a state shows at each step, and a screen reader reads it at each step. |
| A text with `effect :type` | The whole text at once, at the step of the element. The characters that the eye sees have `aria-hidden`, so a screen reader does not read one letter at a time. |

## The language

The `html` element has the `lang` attribute from [the lang option](lang-option.md) of the
deck, and the default is `en`. A screen reader selects its voice from it.

## The contrast

Each text of a theme keeps 4.5:1 on its background. A dimmed text keeps 3:1, or the ratio
of [the dim_contrast option](dim-contrast-option.md). Give `dim_contrast 4.5` for a deck
with small dimmed text, or for a deck that axe-core must pass. See
[the theme option](theme-option.md#the-minimums).

### More contrast

A user can ask the system for more contrast, and the media query `prefers-contrast: more`
is then true. The document changes these parts for such a user:

| Part | With the preference |
| --- | --- |
| Each role of text of the theme | 7:1 or more on its background. See [More contrast](theme-option.md#more-contrast). |
| Each dimmed role | 7:1 or more. See [the dim_contrast option](dim-contrast-option.md#more-contrast). |
| The outline of the cursor of the menu | 3 pixels, and not 2. |
| The outline of the current slide of the menu | 3 pixels, and not 2. |
| The search field of the list of keys | An outline of 3 pixels while it has the focus. |
| The outline of the selected page of the overview | 4 pixels, as in the usual mode. |

## Forced colors

A user can ask the system for forced colors, such as the high contrast mode of Windows.
The browser then replaces the colors of the page with the colors of the system.

### The content of a slide

Each text of a slide takes a color of the system. A graphic keeps its colors on a plate:

| Content | In forced colors |
| --- | --- |
| A text, a callout, a table, a tree, a stat | The colors of the system. |
| A chart | The colors of the theme, on a plate with the background color of the theme. |
| A diagram | Its colors, on the same plate. |
| A formula with a part | Its colors, on the same plate. A step can give a part a color. |
| A formula with no part | The colors of the system. |
| An image | Its colors. The plate shows behind a transparent area. |
| A dimmed element | An opacity of 0.6, because each text has one color. |
| A box of a tree that the `highlight` option dims | An opacity of 0.6, as a dimmed element. |
| A code token in focus | A bar under the token, in the color `CanvasText`. |
| A line of code in focus | A bar at the left of the line, in the color `CanvasText`. It also shows after the key `d`. |
| The cursor of the effect `:type` | A border at the right of the newest character, in the color of the text. `--type-cursor-color` does not apply, and `--type-cursor-width` does. |
| An `embed` | The page in the frame takes the colors of the system too. The edge of the frame does not show. |
| An `audio` element with controls | The controls of the browser, in the color scheme of the system. |
| A `video` element with controls | The controls of the browser. Chromium draws them on a white panel under the picture, and with a black canvas their time does not show. |
| The colors of code | They go away. Each token has the color of the text. |
| A color or a gradient as the background of a slide | It goes away. The slide has the canvas of the system. |
| An image as the background of a slide | It stays. The browser puts a box with the canvas color behind each text. |

The plate is the area of the graphic and 0.25rem on each side. A dimmed line of code has
7.4:1 on a black canvas and 5.7:1 on a white canvas.

### The parts of the presenter

The parts of the presenter take a color of the system, so each one shows:

| Part | Color in forced colors |
| --- | --- |
| The progress bar | `CanvasText`, the color of the text. |
| The dot of the laser pointer | `Highlight`, with a ring of `CanvasText`. |
| A line of the pen | `CanvasText`. |
| A line of the highlighter | `Highlight`, with the opacity of the highlighter. |
| The notes of the speaker view | The colors of the system, as a text of a slide. A link has the color `LinkText`. |

A deck cannot change these colors in forced colors. The properties `--progress-color`,
`--laser-color`, `--draw-pen-color` and `--draw-highlighter-color` apply only in the usual
mode.

## The motion

A reader who asks for reduced motion gets no effect, no transition and no morph.

## The keys

The keys of the presenter are single characters, such as `j` and `p`, and `?` opens the
list of keys. A key does nothing while the focus is in a field of text, such as the search
of the list of keys. See [The presenter](presenter.md).
