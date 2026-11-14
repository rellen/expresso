# The timed advance

This document gives the design for a deck that goes to the next step after a time: the
`advance` option of a slide and of the deck, the `loop` option of the deck, and the clock
of the steps in the presenter. The code contains this design. Issue #402 asked for it. The
document records ten decisions, and each is settled. Its last section, "The result", tells
what changed during the work.

The issue has two parts. This document is for the first part. The second part is the
rehearsal, which records the time of each slide, and it has its own pull request.

## The problem

Some talks move by time. A lightning talk such as Ignite or PechaKucha gives each slide a
fixed time, and a deck on a screen at a stand runs with no presenter. PowerPoint and
Keynote have a time for each slide. Expresso moved only at a key or at a click.

## The plan

1. The DSL gets the option `advance` of a slide and of the deck, and the option `loop` of
   the deck.
2. `Expresso.Steps` writes the time of each step into its entry of the list of the steps.
   With `loop`, the `next` of the last step of the talk is the first step of the talk.
3. The presenter program gets the field `paused` of the state, and the key `a` changes
   it.
4. `advance.ts` holds the rules of the clock of the step that shows. The present view
   goes to the next step when the time ends, and the speaker view shows the time left.

## The decisions

Each decision is settled.

1. **Two pull requests.** The maintainer made this decision. The options `advance` and
   `loop` come first, and the rehearsal comes second.
2. **One key stops and starts the clock of the deck.** The maintainer made this decision.
   The keys of the next step and of the previous step still move, and a new step starts
   its time from zero. A key that stops the clock only for the rest of one step does not
   help a presenter who must answer a question: the next step then moves again.
3. **The time is the time of each step.** A slide with three steps and `advance 15_000`
   shows each step for 15 seconds. A time for the slide as a whole needs a rule that
   divides it between the steps, and the author cannot see that rule in the deck.
4. **The time is in milliseconds.** The `speed` option and each time of an animation are
   in milliseconds. The `duration` option is in minutes, because it is the length of a
   talk.
5. **`advance false` on a slide gives the slide no time.** A presenter opens the deck
   before the talk starts. A title slide with `advance false` waits for a key, and the
   clock starts with the first slide after it.
6. **The list of the steps holds the time and the loop.** An entry holds `advance`, and
   the `next` of the last entry holds the first step of the talk. The two interpreters
   read `next`, so the key of the next step also goes from the last step to the first
   step, and the interpreters need no rule for `loop`.
7. **The present view moves the steps, and each window has its own clock.** The clock
   runs while the field `paused` is false and the screen is not black. The two fields are
   in the option `sync`, so the speaker view has the same clock, with the small
   difference of the time of a message. The speaker view shows the time left, and it
   does not move a step.
8. **The present view looks at the clock four times each second.** One `setTimeout` for
   the time of a step is not correct after the computer stops a window, and a test
   cannot move it. The function compares the time of the clock with the time that the
   step used, as the timer of the speaker view does.
9. **The move of the clock is the move of a fragment of the address.** `fromHash` goes to
   the next step and gives each field of the option `reset` its first value. The model
   in Elixir has the same event, so the clock needs no new command.
10. **The layout check, the export and the browser level of the check have no clock.**
    `?check` in the address gives the present view no clock. The export and the browser
    level open the document with `?paused`, which stops the clock at the load. A picture
    of a step is then a picture of that step.

## The result

The code follows the plan, with these changes:

1. **The move from the last step to the first step goes forward.** The transition of a
   move comes from the numbers of the two slides, so the loop played the transition of
   the last slide in reverse. `transition` in the two interpreters now finds that move
   from the `next` of the entry. The kind then comes from the first slide.
2. **A step does not end while a video or a sound of its slide plays.** The issue named
   this as a possible part. A clip that is longer than the time of its step plays to its
   end. A medium with the `loop` option does not end, so it does not count.
3. **The overview, the menu and the list of keys do not stop the clock.** Only the
   window that shows them knows about them, and the clock of the other window continues.
   A black screen is in the option `sync`, so it stops the clock in the two windows.
4. **A fifth element of the speaker view.** `speaker-advance` holds the time left of the
   step, such as `Next step in 0:12`. A step that waits for a key gives no text.
5. **The recorder of the GIFs takes the frames after a move of the clock.** The action
   `{:advance, milliseconds}` moved the clock for the timer of the speaker view. It now
   also waits for a different step in the present view, and it takes the frames of the
   change.

`docs/reference/advance-option.md` gives the options, and
`docs/how-to/run-a-deck-by-time.md` gives the steps.

## The limits

- The handout view of the present view stops the clock, and the speaker view does not
  know this. Its time left then continues to count.
- The option of the deck gives the same time to each step. The option of a slide also
  takes a list with a time for each step, which the rehearsal added. `docs/rehearsal.md`
  gives that design.
- A deck with one step and `loop true` has no step to go to, so its step has no time.
