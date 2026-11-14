# The laser pointer

This document gives the design for the laser pointer of the presenter: a red dot that goes
with the mouse during the talk. The code contains this design. Issue #397 asked for it.
The document records ten decisions, and each is settled. Its last section, "The result",
tells what changed during the work.

## The problem

The `shape` element marks a part of a slide, but the author must plan each mark before
the talk. During a question, the presenter had no way to point at a line of code or at a
bar of a chart. PowerPoint, Keynote and Google Slides each have a laser pointer. The
cursor of the system is small, and it is hard to see on a projector.

## The plan

1. The presenter program gets the field `laser` of the state, and the key `l` changes
   it, in the present view and in the speaker view.
2. `laser` is a field of the option `sync`, so the two windows have the same value, and a
   field of the option `reset`, so a change of the step turns the pointer off.
3. The renderer writes an element `laser` into each document, and the style sheet makes
   it a dot.
4. While the pointer is on, the script puts the dot at the mouse, and it sends the place
   of the dot to the other window.

## The decisions

Each decision is settled.

1. **The key `l`, and no mouse button.** The maintainer made this decision. A long press
   of a mouse button is hard to find, and a click already changes the step.
2. **No trail.** The maintainer made this decision. A trail needs a timer for each point
   of the dot, and the dot alone shows the place.
3. **A field of the state, in the presenter program.** The key, its row in the list of
   keys, the attribute `data-laser` of the `body` and the message to the other window then
   come from the program, as for the key `d`. The script adds only the dot.
4. **A change of the step turns the pointer off.** The presenter points at a part of one
   step. A dot that stays on moves on the screen with each move of the mouse, also when
   the presenter does not point. The key `d` has the same rule.
5. **The place is a part of the slide, from 0 to 1.** The window of the audience and the
   speaker view have different sizes, and the speaker view shows the slide at 60% of its
   size. A place in pixels is correct in one window only. The box of the slide is the
   window in the present view, and the page of the current step in the speaker view.
6. **A message of its own, with no time.** The message of the position holds a time, and
   a window refuses an older message. The dot moves at each frame, and its place is not a
   part of the state. The message `pointer` holds only `x` and `y`, and the decoder of
   `schema.ts` refuses each other value.
7. **Each window sends its dot.** A presenter with one window points in the present view,
   and a presenter with two windows points in the speaker view. The other window shows the
   dot in each case.
8. **A click or a swipe moves the dot only.** A tap on a touch screen puts the dot at the
   finger. If the tap also changed the step, the pointer turned off at once. The keys
   still change the step. The slide takes `touch-action: none` while the pointer is on, so
   the script gets each move of the finger.
9. **The dot goes away when the mouse leaves the slide.** A dot at the edge of the slide
   points at no part. A finger that leaves the screen keeps the dot, because the presenter
   then points with the dot and not with the hand.
10. **The dot is decoration.** It has `aria-hidden`, and a screen reader reads no change.
    The overview, the menu, a black screen, the handout view and paper show no dot.

## The result

The code follows the plan, with these changes:

1. **The dot is 0.4rem, with a glow.** The issue named no size. The custom properties
   `--laser-color` and `--laser-size` change the dot, and the color is `--danger`.
2. **`slideBox` and `laser` in `dom.ts`, and `laser.ts` for the rules.** `laser.ts` does
   not touch the document, so its tests need no browser.
3. **The recorder of the GIFs moves the mouse.** The action `{:point, x, y}` puts the mouse
   at a part of the window, so a GIF can show the pointer.
4. **The fake page of the tests has the box of the slide.** The tests of `main.ts` give
   the present view the size of the window, and the page of the current step a box of
   its own.

`docs/reference/presenter.md` has the section "The laser pointer", and
`docs/how-to/present-a-deck.md` has the section "Point at a part of a slide".
