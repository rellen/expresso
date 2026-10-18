# The morph option

The `morph` option moves the elements that two neighbor slides share from their place on one
slide to their place on the next slide. The rest of the two slides fades.

## Where you write it

| Place | Value | Default | Effect |
| --- | --- | --- | --- |
| The deck | `:auto`, `:named` or `:off` | `:auto` | The mode for each slide change of the deck. |
| A slide | `:auto`, `:named` or `:off` | the mode of the deck | The mode between this slide and the slide before, in the two directions. |
| An element | a string | none | The key of the element. The element with the same key on the neighbor slide is its partner. |

`Expresso.Builder` takes the same option, such as `deck(slides, morph: :named)`,
`slide("second", morph: :off)` and `stat(42, morph: "total")`.

## The modes

| Mode | Partners |
| --- | --- |
| `:auto` | The elements with the same key, and the elements with the same kind and the same content. |
| `:named` | The elements with the same key only. |
| `:off` | None. The slide change uses its transition only. |

### `:auto`

Two elements are partners when they have the same kind and the same content, and no other
element of the two slides has that kind and that content. The content of each kind is:

| Kind | Content |
| --- | --- |
| The heading of a slide | Its text. |
| An image, a video, a sound, a page | The address of its file. |
| An icon, a QR code | Its drawing. |
| A diagram | The SVG of its file. Two files with the same SVG have the same content. |
| A shape | Its kind and its text. A rectangle and an ellipse are never partners. |
| A code | Its language. |
| A stat | Its label. |
| Each other kind | Its text. |

An element without a text or a drawing, such as an empty text area or a diagram with an
empty `svg` element, gets no signature and has no partner. Give it a `morph` key to move it.
A code without a language and a stat without a label are not empty. Two codes without a
language are partners, and two stats without a label are partners.

Two code elements that are partners also move each token that the two codes share, in
order. A token moves from its place in the old code to its place in the new code.

![A stat moves from the center of a slide into a column](https://raw.githubusercontent.com/rellen/expresso/media/morph.gif)

![The tokens of a function move to their places in a longer function](https://raw.githubusercontent.com/rellen/expresso/media/morph-code.gif)

### `:named`

Only the elements with the same `morph` key are partners. Use this mode when the auto mode
moves an element that must not move.

### A key

Two elements with the same `morph` key are partners in the modes `:auto` and `:named`, and
their kinds can be different. Each element takes a key, such as an item of a list or a
column of a `columns` element. A key must occur one time on each of the two slides. A key
that occurs two times on one slide gives no partner.

![An icon moves from the center of the cover to a column of the next slide and gets smaller](https://raw.githubusercontent.com/rellen/expresso/media/morph-key.gif)

## Rules

- Only a change between two neighbor slides in the present view has a morph. A change of
  the step has none. A jump, such as `Home`, morphs the two slides of the jump.
- A change from or to a black screen, the overview, the menu or the list of keys has no
  morph, because these views cover the slide.
- The slide with the higher number gives the mode in the two directions, as it gives
  [the transition](transition-option.md).
- When a slide change has partners, the rest of the two slides fades, whatever the
  transition of the slide. The transition `:none` has no morph.
- An element inside an element with a partner moves with its parent, and gets no partner of
  its own.
- An element that does not show at the time of the change, such as an element of a later
  step, does not move.
- A code with more than 400 tokens moves as one element.
- The morph lasts `--transition-dur` and uses `--ease`, as the transition does.
- The browser must have the View Transitions API. A reader who asks for reduced motion gets
  no morph.
