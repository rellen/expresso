# The rehearsal

This document gives the design for the rehearsal: the speaker view records the time that
each slide of a talk used, and it gives the lines of the `advance` option for those times.
The code contains this design. Issue #402 asked for it, as the second of its two parts.
`docs/timed-advance.md` gives the first part. The document records ten decisions, and each
is settled. Its last section, "The result", tells what changed during the work.

## The problem

The `advance` option gives each step a time, and the author must know those times. A
talk with a fixed length needs a time for each slide that agrees with the words of the
speaker. PowerPoint and Keynote record the time of each slide while the speaker
rehearses, and they then use those times. In Expresso, the author measured each slide
with a watch.

## The plan

1. The speaker view records the time that each step used, while its timer runs.
2. The key `e` of the speaker view opens a dialog with a table of the time of each slide,
   and with the lines of the `advance` option for those times.
3. `?rehearse` in the address stops the clock of the steps, so the speaker gives each
   step its time with the keys.
4. The `advance` option of a slide also takes a list, with a time for each step.

## The decisions

Each decision is settled.

1. **The speaker view records, and the present view does not.** The speaker view has the
   timer and the notes, and the speaker looks at it in a rehearsal. The audience must
   not see a table.
2. **The record follows the timer.** The timer starts at the first change of the step,
   and the key `r` sets it to zero. The record has the same rules, so the speaker view
   has one clock of the talk. The step that shows before the first change has no time.
   That step is usually the title, which waits for the start of the talk.
3. **Each speaker view records, with no mode.** The time of each slide of the real talk
   is also of use. The record costs one number for each step.
4. **`?rehearse` only stops the clock of the steps.** A deck that already has times must
   not move while the speaker measures new times. The present view then has no clock,
   and the speaker view shows a text in the place of the time left. `?paused` also stops
   the clock, but the key `a` starts it again.
5. **A key opens the table, and the end of the deck does not.** The speaker can stop a
   rehearsal at each slide, and can look at the table and continue. The end of a talk is
   not always the last step, because a deck can end with backup slides.
6. **The table is a dialog of the document.** The renderer writes it with an empty table,
   as it writes the list of keys. `showModal` makes the slide inert, and `Escape` or a
   click outside the dialog closes it. A key in the dialog goes to the browser, so the
   step does not change under the table.
7. **The time of a step, and not only of a slide.** The clock of the steps counts each
   step. The table shows the sum for each slide, and the lines give a time for each step
   of a slide when its steps have different times.
8. **A time rounds to the nearest full second.** A time in milliseconds from a rehearsal
   looks more exact than it is. A time of less than one second gives one second, because
   the option takes no zero.
9. **A slide with no time gets `advance false`.** The speaker did not show it while the
   timer ran. The slide then waits for a key, as the title does.
10. **The lines are text that the speaker selects.** One click on the lines selects each
    of them. A button that writes to the clipboard needs a permission that a document
    from a file does not always have.

## The result

The code follows the plan, with these changes:

1. **The lines are `advance` lines under a comment, and not `slide "intro", advance:
   32_000`.** The issue gave that form as an example. The DSL does not take an option on
   the line of a slide, so that line does not compile. Each line is now the option as the
   author writes it in the slide, under a comment with the name of the slide.
2. **A step with no time in a slide with a time gets a comment.** Such a step gets one
   second in the list, and a comment above the line names the step.
3. **The list of the steps holds the name of each slide.** The script did not know the
   names. `Expresso.Steps` writes `name` into each object of `slides`.
4. **A list of the `advance` option can be shorter than the steps of its slide.** A step
   after the end of the list takes the last time of the list. A slide that gets one more
   step thus keeps a time for each step.
5. **The key `r` also starts a new record.** The text of the key in the list of keys
   tells this.

`docs/reference/presenter.md` has the section "The time of each slide", and
`docs/how-to/rehearse-a-talk.md` gives the steps.

## The limits

- A reload of the speaker view starts a new record.
- The record does not stop on a black screen or while the key `a` has the clock of the
  steps stopped, because the timer does not stop.
- The table has no button that changes the file of the deck. The author copies the lines.
