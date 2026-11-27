# Step 0 of a slide

This document gives the design for a slide that opens with no child of `reveal` on it. Such
a slide gets a step 0 in front of step 1, and the first child still shows at step 1. Issue
#716 asked for it. The code does not contain this design yet. The document records twelve
decisions, and each is settled. Its last section, "Result", will tell what changed during
the work.

## Problem

A list with `reveal true` shows its first item together with the slide:

```elixir
slide "plan" do
  heading "The plan"

  list do
    reveal true
    item "Freeze the code on Monday"
    item "Test on Tuesday and Wednesday"
    item "Release on Thursday"
  end
end
```

The presenter uses `reveal` so that the audience does not read ahead. But the first item
is on the screen before the presenter introduces the slide. The author can write `pause()`
in front of the list, but the author must know about `pause()`, and must write it on each
slide.

PowerPoint, Keynote and reveal.js open a slide with no build on it. Beamer shows the first
item with the slide, and Expresso followed Beamer.

## Two designs

The issue proposed that the first child moves to step 2. The maintainer selected a
different design on 2026-11-27: the slide gets a step 0, and each child keeps its step.

| | The first child moves to step 2 | The slide gets a step 0 |
| --- | --- | --- |
| The slide opens at | Step 1, with no item | Step 0, with no item |
| The three items | Steps 2, 3 and 4 | Steps 1, 2 and 3, as before |
| A box with `at 2`, which showed with the second item | It shows with the first item. The author must change it to `at 3`. | It shows with the second item, with no edit. |
| `labels`, `handout`, a step of a `note`, the `steps` option | Each one is wrong by one, and no error tells the author. | Each one stays correct. |
| The code that changes | The counter walk | The counter walk, the list of the steps, the address, and the two interpreters |

Step 0 costs more work in the code, and it costs the author of an old deck almost
nothing. The other design is the opposite.

## Rules

An **implicit specification** is a `[from: :next]` that the author did not write. Two
things write it:

- The `auto_reveal` option of a slide writes it on each element of the slide that has no
  `at` option.
- The `reveal` option of an element writes it on each child that has no `at` option. For a
  tree, each group of nodes takes one step from the counter in the same way.

1. **A slide has a step 0 when an implicit specification takes step 1.** The counter walk
   does not change: the counter of the slide starts at 1, and the first child still takes
   step 1. The slide then has the steps from 0 to its maximum, and it opens at step 0.
2. **At step 0, only an element with no steps shows.** A heading, the header of a table and
   the axes of a chart show. A child of `reveal` does not show, because its first step is
   1.
3. **No specification can name step 0.** An `at` option, an `on` entity, the `labels`
   option, a `note` and the `goto` option take a step of 1 or more, as before.
4. **A `reveal` element under `auto_reveal` takes no step of its own.** It shows together
   with the first thing inside it that takes a step, which is usually its first child.

A slide with a `pause()` in front of its first child of `reveal` gets no step 0, because
the first child takes step 2. Such a slide does not change at all.

| Slide | Steps before | Steps after |
| --- | --- | --- |
| A `list` with `reveal true` and three items | 1 to 3. The items show at 1, 2 and 3. | 0 to 3. The items show at 1, 2 and 3. |
| A `table` with `header true`, `reveal true` and two rows | 1 and 2. The rows show at 1 and 2. | 0 to 2. The header shows at step 0. The rows show at 1 and 2. |
| A `code` element with `reveal [1, 2]` | 1 and 2. The groups show at 1 and 2. | 0 to 2. The groups show at 1 and 2. |
| A `pause()`, then a `list` with `reveal true` and two items | 1 to 3. The items show at 2 and 3. | The same. |
| `auto_reveal true`, a `text_box`, and a `list` with `reveal true` and two items | 1 to 4. The box shows at 1, the list at 2 with no item, and the items at 3 and 4. | 0 to 3. The box shows at 1, the list and its first item at 2, and the second item at 3. |

A child that does not show yet has `visibility: hidden`, so it keeps its space in the
layout. Thus the other elements of the slide do not move when the first child shows.

## Plan

1. **The mark.** `Expresso.Overlay` gets a mark for an implicit specification, and a
   function that makes one. `auto_reveal`, the `reveal` option,
   `Expresso.Element.Code.build/1`, `Expresso.Element.Math` and the groups of a tree use
   it. A specification of the author has no mark.
2. **The expansion.** `Expresso.Overlay.Expand.slide/1` writes `first_step: 0` into the
   metadata of a slide when a marked specification takes step 1. It applies rule 4 in
   the counter walk. `Expresso.Overlay.Render` gets `first_step/1` and a function that
   returns the steps of a slide, next to `max_step/1`.
3. **The option.** The DSL gets the boolean option `reveal_with_slide` of the deck and of
   a slide, and `Expresso.Builder` takes the same option. With the option, a slide gets
   no step 0, and rule 4 does not apply.
4. **Each list of steps.** No module holds the list of the steps of a slide at this time:
   each one makes its own `1..max`. `Expresso.Steps`, the menu rows of the renderer and
   `--check=browser` read the new function. The handout pages and the export do not
   change. See decision 8.
5. **The list for the presenter.** In `Expresso.Steps.slides/1`, `first` becomes the index
   of the first entry of a slide, `steps` becomes its number of entries, and a new key
   gives its first step. `Expresso.Presenter.Schema` lets a step be 0.
6. **The two interpreters.** `Expresso.Presenter.Interpreter` and `assets/src/` find the
   index of a step from the first step of its slide. An address with no step, the click
   on a page of the overview, a typed slide number and the default of the `goto` option
   go to the first step of the slide. The test fixtures get a deck with a step 0.
7. **The small places.** The start value of `data-step`, the text for a screen reader, the
   message of the rehearsal that names a step, and the help texts that say "step 1 of the
   slide".
8. **The elements that draw from the first step.** The first frame of a tree, the layouts
   of `reflow` and the wait of a copy make a list of steps from 1. Each one also covers
   step 0, and the style sheet gets the rule that shows an element at step 0.
9. **The tests, the examples and the documents.** The unit tests of the expansion get
   each line of the table above. A browser test makes sure that a slide with a revealed
   list opens with no item. The list of `Mix.Tasks.Expresso.Gifs` gets a key for each
   step 0, and the documents tell about step 0.

## Decisions

Each decision is settled. The maintainer answered the five questions of the issue on
2026-11-27, and those answers are decisions 3, 5, 6, 7 and 10. The maintainer made
decisions 1 and 4 on the same day.

1. **The slide gets a step 0, and no step number moves.** The maintainer made this
   decision. "Two designs" gives the comparison. An old deck needs no edit, and the
   presenter presses one more key on each such slide.
2. **A slide has a step 0 only when it needs one.** A slide with no child of `reveal` at
   step 1 has the steps from 1, as before. A step 0 on each slide gives each slide of a
   deck one more key press with no change on the screen.
3. **The option `reveal_with_slide` gives the earlier steps back.** The maintainer made
   this decision. It is a boolean option of the deck and of a slide, with the default
   `false`. An option of a slide replaces the option of the deck for that slide. One
   option for each element is not possible in one form, because `reveal` is a boolean on a
   list, a list on a `code` element and an atom on a `tree`.
4. **With `reveal_with_slide true`, each step is the same as before this change.** The
   maintainer made this decision. The option turns off rule 1 and rule 4.
5. **A slide with no heading and only a `reveal` element opens blank.** The maintainer
   made this decision. A rule that reads the content of the slide is hard to predict. The
   author can give `reveal_with_slide true` on that slide.
6. **One rule for each element with `reveal`.** The maintainer made this decision. The
   rule applies to `list`, `table`, `code`, `chart`, `math`, `tree` and `toc`. A
   derivation opens with no line, and a tree opens with no box.
7. **A step that shows no child gives no step 0.** The maintainer made this decision. The
   groups of the `highlight` option, the frames of a chart, the step of `whole_first`, and
   the steps of `rewrite` and of `reduce` change an element that is on the slide. The
   audience can read nothing ahead. Only a marked specification gives a step 0.
8. **Paper and files have no step 0.** The handout view, a print, `--pdf-steps all` and
   `--png-steps all` start at step 1. The page of step 0 shows less than the page of
   step 1, so it is of no use on paper. An export then writes the same pages and the same
   files as before.
9. **An `at` option of the author keeps its meaning.** `at 1` shows an element together
   with the first child, as before, and not at step 0. An author who wants an element on
   the slide from step 0 gives it no `at` option. `at from: 1` was the same as no `at`
   option, and it is now different on a slide with a step 0.
10. **A `reveal` element under `auto_reveal` shows with its first child.** The maintainer
    made this decision. Before this change, the list showed with no item at its own step,
    so one key press changed nothing on the screen. When nothing inside the element takes
    a step, such as in a list with no item, the element takes its own step. This is the
    only part of the change that moves a step number of an old deck.
11. **The list of the `advance` option starts at the first step of the slide.** The
    rehearsal records the time of step 0, and it writes one time for each step. On a slide
    with a step 0, the first time of the list is thus the time of step 0.
12. **Two pull requests, as a stack.** The first one holds this document, so the
    maintainer can read the design before the code changes. The second one holds the
    code, the tests, the examples and the documents together, because some tests compile
    the code blocks of the documents and render each example.

## What changes for a deck

- A slide with a child of `reveal` or of `auto_reveal` at step 1 opens with no such child,
  and the presenter presses one more key on it. Each step number that the author wrote
  stays correct.
- The address of such a slide is `#3.0` when it opens. `#3` goes to step 0, and `#3.1`
  goes to step 1.
- A deck with the `advance` option takes the time of one more step for each such slide. A
  list of times in the `advance` option of such a slide now starts at step 0. See
  decision 11.
- A slide with `auto_reveal true` and an element with `reveal` loses the step that changed
  nothing, so each later step of that slide is one less. See decision 10.
- A slide that starts with `pause()`, the handout, a print and each export do not change.

To keep each step of a deck, the author adds `reveal_with_slide true` to the deck.

## Limits

- No specification can name step 0. A deck cannot give step 0 a name in `labels`, a `note`
  of its own, or a link from the `goto` option.
- A reader of an address must know that some slides start at step 0 and other slides start
  at step 1.

## Result

The work did not start.
