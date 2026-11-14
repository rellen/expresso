# The zoom

This document gives the design for the zoom of the presenter: a part of a slide that
fills the window during the talk. The code contains this design. Issue #399 asked for it.
The document records ten decisions, and each is settled. Its last section, "The result",
tells what changed during the work.

## The problem

A slide with much detail is hard to read from the back of a room. A question can ask
about a detail that the slide shows small, such as one line of a block of code or one row
of a table. reveal.js zooms to an element at a click with the Alt key, and PowerPoint has
a zoom in the slide show. Expresso had no zoom.

## The plan

1. A click with the Alt key on a slide finds the element under the mouse. `main.ts`
   makes an area from the box of its content, and `zoom.ts` makes the scale and the move
   of the slide from the area.
2. `dom.ts` writes the scale and the move on the `html` element, and the style sheet
   makes the transform of the slide.
3. The area goes to the other window in a message `zoom`.
4. The presenter program gets the field `zoom` of the state. The key `z` changes it, and
   a click with no key then zooms. The key `Esc` calls the built-in function `zoom_out`.

## The decisions

Each decision is settled.

1. **The element under the mouse gives the area.** The maintainer made this decision. A
   rectangle that the presenter drags is more exact, but it needs two movements, and the
   drawing uses the drag. A click outside each element zooms by the factor 2 around the
   point.
2. **A click with the Alt key, and the key `z` for a click with no key.** The maintainer
   made this decision. The Alt key is not available on a touch screen, and some window
   systems move a window at a click with it. The key `z` turns on a zoom where each click
   or tap zooms.
3. **An area is a part of the slide, from 0 to 1.** This is the rule of the laser pointer
   and of the drawing. The two windows can have different sizes, and the same part of the
   slide then fills each one.
4. **The message holds the area, and not the transform.** Each window makes the scale
   from the area. A transform in pixels is correct in one window only.
5. **The transform is on the element that holds the slide.** That element is the present
   view in the present view, and the page of the current step in the speaker view. The
   box of that element after the transform is the box that the laser pointer and the
   drawing use, so a dot and a line are on the same part of a slide with a zoom.
6. **The scale is from 1 to 4, and the slide covers the window.** The area fills the
   window in one direction. A small element, such as one word, does not get more than the
   scale 4. The move keeps each edge of the slide at an edge of the window or outside it,
   so the window shows no space outside the slide.
7. **The zoom is a value of the script, and the field `zoom` is only the mode.** The area
   has four numbers, and a field of the state has one value of a small set. The script
   keeps the area, as it keeps the lines of the drawing.
8. **A change of the step shows the full slide.** The zoom is for a detail of one step.
   The field `zoom` is in the option `reset`, so the next step also turns the key `z`
   off, as it turns the laser pointer off.
9. **The zoom does not go with the laser pointer or with the drawing as a mode.** Each
   uses the click, so each key turns the other two off. A click with the Alt key still
   zooms while the laser pointer or the drawing is on, so the presenter can point at a
   detail of a slide with a zoom.
10. **The zoom is a change for the eyes only.** A screen reader reads the full slide at
    each time, so it reads no change. The transform uses the speed and the easing of the
    theme, and a reader who asks for reduced motion gets no change in progress.

## The result

The code follows the plan, with these changes:

1. **The area is the box of the content, and not the box of the element.** A code element
   or a text box takes the full width of the slide, and its text can be much smaller. The
   box of the element then gives a scale near 1. `elementBox` in `dom.ts` returns the box
   that holds each line of text, each picture and each table of the element. A text of a
   later step does not show, so it gives no box.
2. **An element that gives a scale less than 1.25 zooms around the point.** A sentence
   that takes the width of the slide cannot be larger. The click then zooms by the factor
   2, so each click has an effect.
3. **The page of the speaker view has a cut, and it changes at once.** A page cannot cut
   its own transform, and the page with a zoom covered the page of the next step.
   `clip-path` cuts the page to the part that the transform puts on its box. The cut and
   the transform of a change in progress do not agree, so the speaker view has no
   transition.
4. **The body keeps `overflow: hidden` for the time of the change to the full slide.**
   The slide is larger than the window during that time, and a window with a scroll bar
   moved the slide. The style sheet delays the end of `hidden` by the time of the
   transition.
5. **The drawing follows the slide at each frame of the transition.** The layer of the
   drawing is on the box of the slide. `main.ts` puts the layer on the box again at each
   animation frame from `transitionrun` to `transitionend`.
6. **A press with the Alt key draws no line.** While the drawing is on, a click with the
   Alt key zooms, and it added a dot to the drawing.
7. **The recorder of the GIFs clicks with the Alt key.** The action `{:alt_click, x, y}`
   clicks at a part of the window, and the recorder then takes the frames of the
   transition.

`docs/reference/presenter.md` has the section "The zoom", and
`docs/how-to/present-a-deck.md` has the section "Zoom into a part of a slide".

## The limits

- In full screen, the browser uses `Esc` to leave full screen, and the script does not
  get the key. Click with the Alt key again, or press `z`.
- The zoom has one level. A second click shows the full slide, and it does not zoom more.
- A reload of the present view shows the full slide.
