# The drawing

This document gives the design for the drawing of the presenter: lines that the presenter
draws on a slide during the talk, with a pen or with a highlighter. The code contains this
design. Issue #398 asked for it. The document records ten decisions, and each is settled.
Its last section, "The result", tells what changed during the work.

## The problem

A question in a talk often needs a circle around a part of a slide, or a line that joins
two parts. PowerPoint has ink, reveal.js has a plugin for a chalkboard, and Slidev has
drawings. Expresso had the `shape` element for the marks that the author plans, and no
way to draw during the talk.

## The plan

1. The presenter program gets the fields `draw` and `highlighter` of the state. The key
   `x` changes `draw`, the key `h` changes `highlighter`, and the key `c` calls the
   built-in function `clear_drawing`.
2. The renderer writes an SVG element `drawing` into each document.
3. While `draw` is true, a drag of the mouse or of a finger makes a line. `main.ts` keeps
   the lines of the slide that shows, and `dom.ts` writes a path for each line.
4. Each change of the drawing goes to the other window in a message `drawing`.

## The decisions

Each decision is settled.

1. **The keys `x`, `h` and `c`.** The maintainer made this decision. No key of the
   presenter used them. A test of the interpreter used `x` as a key with no function, and
   it now uses `q`.
2. **A change of the slide removes the drawing.** The maintainer made this decision. The
   drawing belongs to the slide that shows: a change of the step keeps it, and a slide
   that comes back has no drawing. The script then keeps one list of lines, and not one
   for each slide.
3. **The mode stays on.** A change of the step turns the laser pointer off, but a drawing
   can go over more than one step of a slide. The key `x` turns the drawing off.
4. **The laser pointer and the drawing do not go together.** Each uses the mouse, and a
   dot on the line that the presenter draws hides its end. The key `x` turns the pointer
   off, and the key `l` turns the drawing off.
5. **A point is a part of the slide, from 0 to 1.** This is the rule of the laser
   pointer, and `laser.ts` gives the functions. The SVG element has the box
   `0 0 1 1` and the size of the slide, so a path needs no change for a window of a
   different size.
6. **The width of a line is in the units of the page.** With `non-scaling-stroke`, the
   box of the SVG does not make a line wide in one direction. `--draw-scale` is the size
   of the slide in the window, so a line in the speaker view is as thin as its slide is
   small.
7. **The message holds each line of the slide.** A message with only the new point is
   smaller, but a window that misses one message then shows a wrong drawing. The whole
   drawing is a few hundred numbers. A point that is very near to the last point adds no
   point, so a slow drag does not make the message large.
8. **A drag past an edge continues along the edge.** A line that stops at the edge of the
   slide looks as if the mouse stopped. A drag that starts outside the slide draws no
   line.
9. **A click or a swipe draws, and it does not change the step.** This is the rule of
   the laser pointer. A click with no move draws a dot. The slide takes
   `touch-action: none` and `user-select: none` while the drawing is on, so a finger
   draws, and a drag does not select the text.
10. **The drawing is decoration.** The SVG element has `aria-hidden`, and a screen reader
    reads no change. The overview, the menu, a black screen, the handout view and paper
    show no drawing.

## The result

The code follows the plan, with these changes:

1. **`clear_drawing` is a built-in function.** A command of the program changes a field
   of the state, and the lines are not in the state. The key `c` therefore calls a
   function of the script, as the key `r` does for the timer.
2. **The lines are a value of `main.ts`, in front of the first state.** The first state of
   the address shows before the later parts of the file. A load at a later slide read
   the lines before their declaration, and the tests of the fragment found this defect.
3. **A speaker view that loads gets the drawing.** The present view answers a request of
   the speaker view with its state, and then with its drawing.
4. **The recorder of the GIFs drags the mouse.** The action `{:drag, points}` presses the
   button at the first point and moves through each next point.
5. **A path takes its namespace from the element `drawing`.** A script that makes an SVG
   element usually holds the address of the SVG namespace. A test makes sure that the
   document names no address of a network, so the script reads the namespace of the
   element that the renderer wrote.

`docs/reference/presenter.md` has the section "The drawing", and
`docs/how-to/present-a-deck.md` has the section "Draw on a slide".

## The limits

- A reload of the present view removes the drawing.
- The drawing has no key to remove only the last line.
