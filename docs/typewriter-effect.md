# The typewriter effect

This document gives the design for the effect `:type`, which shows the text of an element
one character at a time, as if you type it. The code contains this design. Issue #405 asked
for it. The document records ten decisions, and each is settled. Its last section, "The
result", tells what changed during the work.

## The problem

A talk about code often types a command or a line of code. To type it during the talk is
slow, and an error stops the talk. A video of the text is hard to change. Keynote has a
typewriter build, and some themes of Slidev type code. Expresso showed a whole element or
a whole line at a step.

## The plan

1. `effect :type` is a value of the `effect` option. The style sheet of the theme has a
   rule for `[data-effect="type"]`, so `Expresso.Overlay.EffectVerifier` knows the effect.
2. `Expresso.Overlay.Typewriter.wrap/1` puts each character of an element with steps and
   with the effect into its own `span`, with its position in the custom property `--i`. It
   writes the number of the characters into `--type-n` on the element.
3. `Expresso.Renderer` calls the function for the body of each slide of the present view.
4. The style sheet moves the registered property `--type` from 0 to 1 when the element
   shows. A character shows when `--type` passes its position.
5. The presenter script writes `data-back` on a slide after a step back, and the style
   sheet then gives the change no time.

## The decisions

Each decision is settled.

1. **The unit is one character.** A word at a time does not look like a keyboard. A
   character is one grapheme, so a letter with an accent and an emoji of many code points
   are one character. A character reference, such as `&amp;`, is one character. White
   space has no position, so the indentation of a line of code takes no time.
2. **A transition of a custom property, and no script.** The element has one transition:
   `--type` goes from 0 to 1. Each character reads the property, which inherits. The
   recorder of the GIFs and a browser test move a transition to a time, and they cannot
   move a timer of a script. The issue named an animation of the width with `steps()`. A
   width does not work for a text of more than one line, or for a font with letters of
   different widths.
3. **The renderer makes the characters, and only in the present view.** CSS cannot select
   one character of a text. The renderer writes the document, so it can divide the text
   with no script in the page. A page of the handout view and a copy in the menu do not
   move, so they keep the text as it is. The document of a slide with five steps holds
   seven copies of the slide, and six of them stay small.
4. **Each element with text takes the effect.** The function reads the HTML of the slide,
   and not the struct of one kind of element. A text area, an item, a list, a callout and
   a code element therefore type with no code of their own. A picture, a formula, a
   diagram and the number of a line of code keep their content, and they show at once with
   the element. An element with no character loses the effect, and it fades.
5. **An element inside with its own steps is not part of the text.** It shows at its own
   steps. With the effect, it types its own text there. A part of a text from
   `docs/inline-steps.md` is such an element, so one word can type at a later step.
6. **Elements with the same parent and the same steps make one sequence.** The lines of
   one group of a code element with `reveal` are such elements. The second line starts
   after the last character of the first line. Without this rule, each line of the group
   types at the same time.
7. **The time is 40 ms for each character.** That is 25 characters in a second, which is
   faster than a person and slow enough to read. The custom property `--type-char` of the
   theme gives a different time. `speed :fast` gives one half of that time to each
   character, and `speed :slow` gives two times that time. A number of milliseconds is the
   time of the whole text, because a presenter knows how long the text can take. Each
   other change of the element, such as a state, keeps the time of its parent.
8. **The cursor shows only while the text types, and it does not blink.** The newest
   character has a bar on its right side, in the color of the text. A blink is not visible
   at 25 characters in a second. A cursor that blinks after the text is complete moves
   with no end, and WCAG 2.2.2 then asks for a control that stops it. The custom
   properties `--type-cursor-width` and `--type-cursor-color` change the bar.
9. **A text shows at once when it does not come from a step forward.** The text hides at
   once at the last step of the element. After a step back, a text that shows again is
   complete at once, because the audience already read it. A slide that comes into view
   shows its text complete, as each element of step 1 shows with no fade. A reader who
   asks for reduced motion gets the whole text at once.
10. **A screen reader reads the whole text at once.** Some screen readers stop at each
    `span`, and they then read one letter at a time. Each run of text is therefore in the
    document two times. The first copy has the class `type-text`. It has no size, so the
    eye does not see it, and a screen reader reads it. The characters have `aria-hidden`.
    The text does not change during the effect, so a screen reader gets no update for
    each character.

## The result

The code follows the plan, with these changes:

1. **White space goes into the `span` of a character.** `Expresso.Deck.render/1` writes the
   document with Floki, which drops a text of white space only between two tags. A space
   between two characters is such a text. The space therefore goes into the `span` of the
   character before it, and the cursor shows after the space.
2. **The cursor stays at the moment of the next character.** The recorder of the GIFs
   takes a picture at each 40 ms, which is the moment when a character comes. The first
   rule showed no cursor at that moment, so the GIF had no cursor. The cursor now stays on
   a character until the next character shows.
3. **The first copy of a text has no line height.** A box with a font size of zero can
   make its line higher when the line height is a length. The copy has `line-height: 0`,
   so a text with the effect has the same place as a text with no effect.
4. **The fake element of the tests has `toggleAttribute`.** `dom.ts` writes `data-back`
   with it, and the fake slide of `assets/test/` had no such function.

`docs/reference/overlay-options.md` has the section "The effect `:type`", and
`docs/how-to/animate-elements.md` has the section "Type a text or a line of code".

## The limits

- The text of step 1 of a slide shows with the slide. Put `pause()` in front of the
  element to make its text type at step 2.
- The cursor is on the right side of a character. A text from right to left has it on
  the wrong side.
- A picture, a formula and an icon in a text show at once, and they have no position in
  the sequence.
