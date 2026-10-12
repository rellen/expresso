# The accessibility of a deck

This page gives what the document of a deck tells a screen reader, and what the deck must
give. For the steps, see [Make a deck accessible](../how-to/make-a-deck-accessible.md).

## The landmarks

| Element | Role | Holds |
| --- | --- | --- |
| `main.views` | `main` | The present view, the handout view, the progress bar and the live region. |
| `nav#menu` | `navigation`, with the name "Slides and steps" | The menu. |
| `dialog#help` | `dialog`, with the title of the list | The list of keys. |
| `aside.notes` | `complementary`, with the name "Notes: " and the name of the page | The notes of a page of the handout view. |

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

## The live region

`div#announce` has the role `status`, so a screen reader reads each change of its text and
does not stop what it reads. The screen and paper do not show it.

| Move | Text |
| --- | --- |
| To a different slide | The name of the slide, with its step when it has more than one step, such as `Slide 2 of 3, step 1 of 2: A restart`. |
| To a different step of the same slide | The step, such as `Step 2 of 2`. |
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
| `chart` | An `img` with the `title` option as its name, and a table of the values. |
| `stat` | The whole value as one text, such as "$4.2M", and the `label` option. |
| `icon` | Nothing for the drawing. The `label` option as text. |
| `qr_code` | An `img` with the `title` option, or the text of the code, as its name. |
| `video`, `audio`, `embed` | The `title` option as the name of the element. |
| `callout` | A `note`, with the header as text. |
| `math` | MathML, which a screen reader reads. |
| An element of a later step | Nothing. The style sheet hides it with `visibility: hidden` until its step. |

## The motion

A reader who asks for reduced motion gets no effect, no transition and no morph.

## The keys

The keys of the presenter are single characters, such as `j` and `p`, and `?` opens the
list of keys. A key does nothing while the focus is in a field of text, such as the search
of the list of keys. See [The keys](../../README.md#the-keys).
