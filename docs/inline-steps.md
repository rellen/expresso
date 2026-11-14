# Steps inside a text

This document gives the design for a part of a text that shows or changes at its own
steps, such as one word of a sentence. The code contains this design. Issue #404 asked for
it. The document records ten decisions, and each is settled. Its last section, "The
result", tells what changed during the work.

## The problem

The overlays of `docs/overlays.md` give steps to an element, to an item of a list, to a
line of code and to a part of a chart. A text area could not give a step to one word of a
sentence. A talk often needs this: the last word of a question shows at the next step, or
a key phrase changes its color when the presenter says it. Beamer has `\only<2>{...}` and
`\alert<2>{...}` inside a text.

## The plan

1. A tag in the text of a text area or of an item takes the attribute `at`, with a step
   specification in text, and the attribute `state`.
2. `Expresso.Overlay.Inline.extract/1` makes an `Expresso.Element.TextPart` for each such
   tag, as a child of the text element. It runs at the start of
   `Expresso.Overlay.Expand.slide/1`.
3. The expansion of the overlays gives each part its steps, and
   `Expresso.Overlay.Render.identify/1` gives a part with a state its identity.
4. The render of the text element writes the attributes of the overlay contract into the
   tag of each part.

## The decisions

Each decision is settled.

1. **An attribute of a tag, and not a new markup.** The text of a text area is HTML, and
   an author already writes `<em>` and `<sup>` in it. The attribute `at` on a tag needs no
   new escape rule. The alternative `{2:42}` is shorter, but a text with braces, such as
   a map of Elixir, then needs an escape. An entity of the DSL for each part divides one
   sentence into many lines.
2. **The forms of the `at` option, in text.** An attribute holds text, so the
   specification has a text form: `2`, `2-4`, `2-`, `+` and `+-`, with commas for a list.
   These are the forms of Beamer. Each form has one form of the `at` option of an element,
   and `Expresso.Overlay.Inline.spec/1` makes the same struct.
3. **A part is a child of its text element.** The parts go into the `elements` of the
   text area or of the item. The counter walk, the maximum step, the errors, the
   identities and the rules of the style block then apply to a part as they apply to an
   element. The alternative is a second mechanism only for a text, with its own counter
   and its own rules.
4. **The counter goes through the parts in the order of the text.** A part reads the
   counter after the `at` option and the `on` entities of its element, and in front of the
   next element. An item reads its parts in front of its nested list, because the text of
   an item comes first.
5. **`state` changes the meaning of `at`.** Without `state`, `at` gives the steps that
   show the part. With `state`, the part shows at each step, and `at` gives the steps of
   the state, as the first argument of an `on` entity does. A part then needs one
   attribute for its steps. A part with steps and with a state is a tag in a tag.
6. **The states are `alert` and `dim`.** They are the two states of the `on` entity. The
   `set` option of `on` moves an element or changes its size, and a part of a line of text
   cannot move.
7. **The state `alert` changes the color.** An element with the state `alert` gets an
   outline. A part is in a line of text, and an outline around some words is hard to read
   when the part breaks into two lines. The part takes the accent color, as `\alert` does
   in Beamer. The custom property `--text-part-alert-color` gives a different color.
8. **A hidden part keeps its space.** A part with steps is an element with `data-on`, and
   the style sheet hides it with `visibility: hidden`. The text around it does not move at
   the step, as a hidden line of code keeps its place.
9. **A part fades, and the `effect` option does not change it.** The effects move an
   element or change its size with a transform, and a transform does not apply to an
   inline box. An inline block takes a transform, but it cannot break into two lines. The
   effect `:type` of `docs/typewriter-effect.md` came later. It uses no transform, so a
   part of a text with that effect types.
10. **A screen reader reads a part at its steps.** A part of a later step is hidden with
    `visibility: hidden`, as an element of a later step is, so a screen reader reads the
    sentence as the audience sees it. The issue asked for the whole sentence at each step.
    That is not the rule of an element, and two rules for the same attribute are worse.

## The result

The code follows the plan, with these changes:

1. **No callout.** The issue named a callout. A callout has no text of its own: its text
   is in the text areas and the lists inside it, and they take the parts.
2. **A text area has the field `elements`.** A text area was a leaf of the tree. It now
   holds its parts in `elements`, which is the field that `Expresso.Element.Tree` reads.
   An item already had the field for its nested list, so it holds its parts in front of
   the list, and it renders only the list.
3. **The dim of a part needs no rule.** A part with a state has an identity, and the rule
   of the theme for `[data-el]` already moves the color of an element to its dimmed color.
   The one new rule of the style sheet gives the state `alert` its color.
4. **The extraction is safe to run two times.** `extract/1` changes the attributes of a
   tag into `data-text-part`. A second call finds no attribute `at`, so it changes nothing.

`docs/reference/overlay-options.md` has the section "A part of a text", and
`docs/how-to/animate-elements.md` has the section "Show a word at its own step".
