# The css option

The `css` option of a deck adds a style sheet to the theme. The document puts the style
sheet after the theme and after the generated rules. A rule of the deck can therefore
replace each rule of the theme, and it can give new effects, new transitions and new
states.

## The forms

| Value | Style sheet |
| --- | --- |
| `css ~S"""` and the rules on the next lines | The rules. A value with a brace or a line break is a style sheet. |
| `css "deck.css"` | The file at this path, relative to [the root option](root-option.md) of the deck, or to the working directory of the command without it. |

A rule of the style sheet applies to each slide. To style one slide or one element, give it
a class name with [the class option](class-option.md), and write a rule for that class.

A file that the compiler cannot read gives an error at compile time. A deck from
`Expresso.Builder` takes the same option, such as `deck(slides, css: "deck.css")`, and the
renderer reads the file.

The text `</` can close the `style` element, so the renderer writes `<\/`. CSS reads the
two forms in the same way in a string, a comment or a URL.

## Files in the style sheet

The document is one file, so the renderer puts each local file of a `url()` into the style
sheet as a data URI. A rule can thus use a font or a picture of the deck:

```css
@font-face {
  font-family: "Talk";
  src: url(fonts/talk.woff2) format("woff2");
}
```

| `url()` in | Start of a relative path |
| --- | --- |
| A CSS file, such as `css "styles/deck.css"` | The directory of that file, as in a browser. |
| A style sheet in the option itself | [The root option](root-option.md) of the deck, or the working directory without it. |

- These types go into the document: `.woff2`, `.woff`, `.ttf` and `.otf` fonts, and the
  image types of the `image` element.
- An address, such as `https://example.com/font.woff2`, a `data:` URI and a fragment, such
  as `url(#shadow)`, stay as they are.
- A query of the path, such as `?v=2`, is not part of the file name. A fragment of a file,
  such as `icons.svg#arrow`, stays after the data URI.
- The renderer raises an `ArgumentError` for a file that it cannot read, and for a file of
  another type.
- The watch mode renders the deck again after a change to a file of `url()`.

For the steps, see [Put a picture or a font into the style sheet](../how-to/put-files-into-the-css.md).

## New effects

A rule for `[data-effect="name"]` gives the effect `:name`. Write hyphens in the CSS and
underscores in the deck, as `[data-effect="fly-far"]` for `effect :fly_far`. The compiler
gives an error for an effect without a rule in the theme or in the style sheet.

An effect can set these properties of the theme. The theme moves the element from them to
its place when the element shows, and back when it hides.

| Property | Syntax | Default |
| --- | --- | --- |
| `--enter-x`, `--enter-y` | a length | `0px` |
| `--enter-scale` | a number | `1` |
| `--enter-blur` | a length | `0px` |
| `--enter-animation` | the name of `@keyframes` | `none` |
| `--exit-animation` | the name of `@keyframes` | `none` |

The theme plays `--enter-animation` when the element shows, and `--exit-animation` when
it hides, with the time and the easing of the element. A transition wins over an animation
for the same property. Keyframes that change `transform` therefore play in full, but
keyframes that change `opacity` have no effect during the fade.

## New transitions

A rule for `html[data-transition="name"]` gives the transition `:name` between slides. Write
hyphens in the CSS and underscores in the deck, as `[data-transition="wipe-down"]` for
`transition :wipe_down`. The rule animates `::view-transition-old(slide)` or
`::view-transition-new(slide)`. The compiler gives an error for a transition without a rule
in the theme or in the style sheet. For the selectors, see
[The transition option](transition-option.md#a-transition-of-the-css-of-the-deck).

## New states

`on 3, state: :mark` sets `--mark: 1` on the element at step 3, and `0` at the other
steps. A rule of the deck reads it, such as
`background: color-mix(in srgb, #ffe066 calc(var(--mark, 0) * 100%), transparent)`. Write
the fallback `0`, because a deck without the state registers no property for it. The
compiler gives no warning for a state or a `set` key that the style sheet uses.

The theme lists the properties that each element animates in `transition`. A rule of the
deck that sets `transition` replaces that list, so a new state usually changes at once.

## The properties of the theme

A rule of the deck can set or read these custom properties of the theme:

- The timing: `--dur`, `--ease`, `--motion` and `--transition-dur`.
- The overlays: `--x`, `--y`, `--scale`, `--rotate`, `--opacity`, `--color`, `--alert`,
  `--dim`, `--dimmed`, `--dim-opacity` and `--shown`.
- The parts of the page: `--slide-padding`, `--progress-color`, `--progress-height`,
  `--slide-number-color`, `--slide-number-size`, `--slide-number-right`,
  `--slide-number-bottom`, `--overview-color`, `--pace-behind-color` and
  `--pace-over-color`.
- The colors: each role of [the theme option](theme-option.md), such as `--text`,
  `--accent` and `--code-keyword`, and the dimmed color of each role of text, such as
  `--text-dim`. A role that a rule of the deck replaces gets no check of its contrast.

`--dimmed` is 1 in a dimmed element and in each element inside it, and 0 in other
elements. A `dim` key of `set` gives it a value between 0 and 1. The theme mixes each color
of text toward its dimmed color with this value. A rule of the deck that gives a color to
text does not dim. To make it dim, see
[Make a color of your own dim](../how-to/style-one-slide.md#make-a-color-of-your-own-dim).

![A box that bounces in, a box that drops in, and a marker](https://raw.githubusercontent.com/rellen/expresso/media/overlay-custom.gif)
