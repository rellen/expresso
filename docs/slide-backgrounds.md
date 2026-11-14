# Slide backgrounds

This document gives the design for the background of a slide: an image, a color or a
gradient behind its content. The code contains this design. Issue #403 asked for it. The
document records ten decisions, and each is settled. Its last section, "The result", tells
what changed during the work.

## The problem

A title slide or a section slide often has a photo behind its text. Before this design,
the author wrote a class and a rule of the `css` option, and the image went into the style
sheet as a data URI. `docs/how-to/put-files-into-the-css.md` gives those steps, and they
are long for a common need. A rule of the author also has no check for the contrast of the
text on the photo.

## The plan

1. A `background` option of a slide and of the deck. `Expresso.Background.option/1` makes
   a struct from each form of the value.
2. `Expresso.PathTransformer` joins the path of the image to the `root` option.
3. The renderer writes the background as the first element of each copy of the slide, and
   the style sheet puts it behind the content.
4. The accessibility check measures the contrast of each text on the background.

## The decisions

Each decision is settled.

1. **One option with a keyword list.** `background` takes a path, or a keyword list with
   one of `image`, `color` and `gradient`. The alternative is an option for each kind,
   such as `background_image` and `background_color`. One option gives one place for the
   default of the deck and for `:none`.
2. **The image is an element, and not a rule of the style sheet.** The renderer writes an
   `img` element with a data URI. `Expresso.Assets.dedupe/1` then keeps one copy of a large
   file for the copies of the slide, as it does for an image element. A `background-image`
   in a `style` attribute puts the file into the document one time for each copy: the
   present view, each page of the handout view and the menu.
3. **The slide is a stacking context.** A slide with a background gets
   `isolation: isolate`, and the background gets `z-index: -1`. The background is then
   behind each part of the slide and in front of the color of the slide. No other part of
   the slide gets a new position, so the rules of the templates and of the shapes do not
   change.
4. **A color is a role or a hex color.** A role, such as `:accent`, becomes its custom
   property, so the background follows the theme and its variant. A hex color is for a
   color of a brand. The option refuses each other text, so a value cannot put a rule into
   the `style` attribute.
5. **The dim layer has the background color of the theme.** `dim: 0.4` puts a layer in
   `--background` over the image. The text of a theme has its contrast on that color, so
   the layer moves the image toward the color that the text needs: darker in a dark theme,
   lighter in a light theme. A black layer is wrong for a light theme.
6. **The compiler gives no warning for the contrast.** The compiler cannot see the image.
   A warning for each image with no `dim` is also a warning for a dark photo under light
   text, which is correct. The check measures the contrast in the browser.
7. **The check measures the text on a canvas.** axe-core gives no contrast for a text on
   an image or on a gradient. The page draws the layers of the background on a canvas, as
   the style sheet shows them, and it compares the color of each text with the pixels
   behind it. The result is a finding with the rule `background-contrast`, in the form of
   a finding of axe-core.
8. **The measure uses the lowest contrast of a small canvas.** The canvas is not more than
   480 pixels wide. One pixel is then the mean of a small area, so one bright point of a
   photo does not fail a text, and a text on a bright half of a photo fails.
9. **The background is a part of the slide for a transition.** With the default
   transition `:fade` and with the morph, the browser fades the old slide into the new
   slide. Two slides with the same background then show the same pixels in the two
   pictures, so the background does not change. `:slide` and `:zoom` move the background
   with the slide, as they move each other part. A background that stays in its place
   during a `:slide` needs the content of the slide in an element of its own.
10. **No video in the first version.** A video background must loop, must have no sound,
    and must play only on the slide that shows. `assets/src/video.ts` has rules for a
    `video` element, and a background needs its own. An image, a color and a gradient are
    the common needs.

## The result

The code follows the plan, with these changes:

1. **The measure does not wait for a promise.** The check runs the browser with a virtual
   clock, and that clock does not wait for the decode of an image. The first version
   waited for `decode()`, and the browser sometimes wrote the document before the check
   ended. The document holds the image as a data URI, so the image is complete at the
   load, and the canvas decodes it when it draws it.
2. **The check measures each kind of background.** A color is a layer behind the slide, as
   an image is, so the measure draws it too. The check then gives one rule for each kind.
3. **The note for an image with no `alt` skips the background.** The check with no tool
   gives a note for an `img` with an empty `alt`. The image of a background is decoration,
   and it has `aria-hidden` on its container, so it gives no note.
4. **The notes of a page of the handout view get a color.** The notes are under the slide
   in the same page, so the background was behind their text. A rule gives the notes the
   background color of the theme.
5. **The example of the guide needed a dim layer.** The check found a heading with too
   little contrast on the gradient of the first example. The example now gives the
   gradient `dim: 0.4`.

`docs/reference/background-option.md` is the reference of the option, and
`docs/how-to/put-a-picture-behind-a-slide.md` gives the steps.
