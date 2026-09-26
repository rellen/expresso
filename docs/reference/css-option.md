# The css option

The `css` option of a deck adds a style sheet to the theme. The document puts the style
sheet after the theme and after the generated rules. A rule of the deck can therefore
replace each rule of the theme, and it can give new effects and new states.

## The forms

| Value | Style sheet |
| --- | --- |
| `css ~S"""` and the rules on the next lines | The rules. A value with a brace or a line break is a style sheet. |
| `css "deck.css"` | The file at this path, relative to the working directory of the command. |

A file that the compiler cannot read gives an error at compile time. A deck from the
imperative API gives the same value in the `:css` key of the metadata of the deck, and the
renderer reads the file.

The text `</` can close the `style` element, so the renderer writes `<\/`. CSS reads the
two forms in the same way in a string, a comment or a URL.

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
  `--dim`, `--dim-opacity` and `--shown`.
- The parts of the page: `--progress-color`, `--progress-height`, `--slide-number-color`,
  `--slide-number-size`, `--slide-number-right`, `--slide-number-bottom`,
  `--overview-color`, `--pace-behind-color` and `--pace-over-color`.

![A box that bounces in, a box that drops in, and a marker](https://raw.githubusercontent.com/rellen/expresso/media/overlay-custom.gif)
