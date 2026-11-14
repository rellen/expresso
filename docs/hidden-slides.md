# Hidden slides

This document gives the design for a slide that the talk skips, such as a backup slide for
the questions after the talk. The code contains this design. Issue #401 asked for it. The
document records twelve decisions, and each is settled. Its last section, "The result",
tells what changed during the work.

## The problem

A talk often has slides that the presenter shows only when a question needs them: a detail
of a chart, a slide of numbers, or an answer to a common question. PowerPoint and Keynote
can hide a slide, so the slide show skips it. In Expresso, each slide showed in sequence.
Thus the author put such slides after the last slide of the talk, and the progress bar and
the slide numbers counted them.

## The terms

- The **talk** is the slides that are not hidden, in the sequence of the deck.
- A **hidden slide** is a slide with `hidden true`. It keeps its place in the deck, and it
  is not a part of the talk.
- The **place** of a slide is its number in the deck. The first slide has the place 1, and
  a hidden slide has a place too.
- The **number** of a slide is its number in the talk. A hidden slide has no number.

## The plan

1. The slide option `hidden true` and the deck option `handout_hidden true`.
2. `Expresso.Deck.number_slides/1` writes the place of each slide as `:slide_number` and
   its number as `:talk_number`.
3. `Expresso.Steps` gives each step the index of the step before it and of the step after
   it in the talk, and it gives each slide its number. It counts `fraction`, `done` and
   the text of the position only from the talk.
4. The two interpreters of the presenter program read these values. They have no rule of
   their own for a hidden slide.
5. The renderer writes the numbers, the marks of the overview and of the menu, and the
   attributes that leave a hidden slide out of the handout view and of paper.

## The decisions

Each decision is settled.

1. **An option of the slide.** `hidden true` is a boolean option, as `auto_reveal` is. The
   alternative is a section of the deck for the backup slides. An option lets the author
   put a backup slide after the slide that it supports.
2. **A slide has a place and a number.** The place gives the slide its identity: the `id`
   of its section, the address `#5.1`, a message between the two windows, and a link by
   number of the `goto` option. These values must not change when the author hides a slide.
   The number is the value that the audience and the presenter see.
3. **The numbers count only the talk.** The slide numbers, such as `3 / 12`, the text
   `Slide 4 of 13` in the speaker view and the progress bar count only the slides of the
   talk. The audience then sees no gap in the numbers, and the last slide of the talk shows
   `12 / 12`. The alternative keeps a number for each slide, as PowerPoint does, and the
   audience then sees `11 / 14` on the last slide.
4. **A typed number is a number of the talk.** The presenter types the number that a slide
   shows. A hidden slide has no number, so a typed number cannot go to it. The issue also
   asked for a typed number that goes to a hidden slide. That needs a second set of numbers
   for the hidden slides, which the presenter must learn. The overview, the menu, a link
   and the address go to a hidden slide.
5. **The steps model holds the moves.** Each entry of `Expresso.Steps` holds `previous`
   and `next`: the index of the step that `k` and `j` go to, or `nil`. The command
   `{:step, count}` reads them, and the mark of the next step in the speaker view reads
   `next`. Thus the rule is in one function in Elixir, and the script only reads values.
6. **On a hidden slide, the keys go through its steps and then into the talk.** `previous`
   and `next` go to the nearest step of the same slide or of a slide of the talk. After the
   last step of a hidden slide, `j` goes to the next slide of the talk. Two hidden slides
   in sequence are one gap: `j` on the first does not go to the second.
7. **The progress bar does not move on a hidden slide.** A step of a hidden slide takes the
   `fraction` and the `done` of the last step of the talk before it. The pace in the
   speaker view then does not change while the presenter answers a question.
8. **The handout view and paper leave out a hidden slide.** A handout is a record of the
   talk. The deck option `handout_hidden true` puts each hidden slide in, in its place,
   with the pages of its `handout` option. The alternative puts the hidden slides at the
   end, under a heading. That needs a second sequence of pages in the document.
9. **The key `a` does not show a hidden slide.** `a` shows each step of each slide that the
   handout view shows. A page of a hidden slide has `data-omit="hidden"`, and the rule for
   that value does not depend on `a`.
10. **The mark is a dashed outline and a lower opacity.** The overview and the menu show a
    hidden slide with the two marks, so the mark does not use only the opacity. The menu
    shows a dash in the place of the number, and a screen reader reads "Hidden slide".
11. **The deck starts at the first slide of the talk.** The first value of the field
    `index` of the program is step 1 of that slide, and the renderer shows that slide
    before the script starts. `Home` and `End` go to the first slide and to the last slide
    of the talk. In the overview, `End` selects the last slide of the deck, because the
    overview shows each slide.
12. **A deck with only hidden slides compiles.** It has no talk. It starts at its first
    step, and `j` and `k` go only through the steps of the slide that shows. A verifier
    that refuses such a deck adds a rule for a case that has no use.

## The result

The code follows the plan, with these changes:

1. **The mark of the next step counts the steps of the talk.** The projection
   `mark "data-speaker", ".handout-page", :index, [..., {"next", :index, 1}]` held an
   offset that the script added to the index. An offset of an `:index` now counts the steps
   of the talk, so the script goes through `next` that number of times.
2. **A new symbol `first_slide/0`.** `Home` was `goto(0)`. It is now
   `goto(first_slide())`, and `Expresso.Presenter.Program` changes the symbol into the
   index of step 1 of the first slide of the talk. `last_slide/0` with `goto/1` is the last
   slide of the talk, and with `select/1` it is the last slide of the deck.
3. **`handout_hidden` is a key of the metadata only for a deck that gives it.** The other
   boolean options of the deck have a default in the metadata. This option follows
   `dim_contrast` and `window`, so the metadata of a deck without the option does not
   change.
4. **The fixtures of the script hold hidden slides.** One slide in four of each random deck
   of `Expresso.Test.PresenterFixtures` is hidden. The test of `assets/test/` then makes
   sure that the script interpreter returns the result of the Elixir interpreter for a
   deck with hidden slides.
5. **The page breaks of the handout view.** A page of a hidden slide has `display: none`.
   The rules of `break-before` name `data-omit="hidden"`, so the first page that shows
   does not start a new sheet when a hidden slide is in front of it.

`docs/reference/hidden-option.md` is the reference of the option, and
`docs/how-to/keep-backup-slides.md` gives the steps.
