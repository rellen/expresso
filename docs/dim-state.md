# A dim state with a color for each role

This document gives a plan for the state `dim`, and the record of its result. The code
contains this plan. The plan depends on pull request #128, which adds the APCA minimums to
each theme. The document ends with four decisions, and each is settled. "The result"
gives the four places where the code is different from the plan.

## The problem

The state `dim` gives an element a filter with one opacity, the dim opacity of the theme.
The filter applies that opacity to each color of the element. After #128, the dim opacity
is the smallest multiple of 0.05 that keeps each role of text at 3:1 and at Lc 30 on its
background. "The contrast of a theme" in `docs/architecture.md` gives the formulas.

Each role is near its own minimum, because the palette adjusts a role only until it meets
the minimum. Thus the role with the lowest contrast sets the opacity for all the roles. A
dimmed list item has only the color of the text, but it dims as little as a dimmed comment
can dim.

This table gives the shared opacity of #128, and the opacity that each role could take
alone at the same minimums. A lower value dims more.

| Theme | Shared | `text` | `muted` | `accent` | `code_text` | `code_comment` | `code_keyword` | `code_string` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `:default` | 0.8 | 0.45 | 0.65 | 0.7 | 0.45 | 0.7 | 0.6 | 0.8 |
| `:github` | 0.8 | 0.6 | 0.8 | 0.75 | 0.6 | 0.8 | 0.65 | 0.55 |
| `:solarized_light` | 0.8 | 0.75 | 0.8 | 0.75 | 0.8 | 0.8 | 0.8 | 0.8 |
| `:tokyo_night_light` | 0.75 | 0.65 | 0.7 | 0.75 | 0.65 | 0.75 | 0.75 | 0.75 |
| `:dracula` | 0.65 | 0.45 | 0.6 | 0.6 | 0.45 | 0.65 | 0.65 | 0.5 |
| `:catppuccin_mocha` | 0.65 | 0.5 | 0.65 | 0.65 | 0.55 | 0.65 | 0.65 | 0.55 |
| `:gruvbox_dark_hard` | 0.65 | 0.55 | 0.65 | 0.65 | 0.55 | 0.6 | 0.6 | 0.6 |
| `:solarized_dark` | 0.65 | 0.65 | 0.65 | 0.6 | 0.6 | 0.6 | 0.6 | 0.6 |
| `:tokyo_night_storm` | 0.65 | 0.6 | 0.6 | 0.6 | 0.65 | 0.65 | 0.65 | 0.6 |

The text of `:default` and `:dracula` could dim to 0.45, in place of 0.8 and 0.65. The gain
is small for a theme with a text of low contrast, such as `:solarized_light`.

## The constraints

- Each dimmed color stays at 3:1 and at Lc 30 on its background, the minimums of #128.
- The output stays one HTML file. CSS cannot calculate a contrast, so `Expresso.Palette`
  calculates each dimmed color at compile time.
- The change of the state animates, as the filter animates today.
- The `css` option of a deck can replace a role, such as `--text`. A deck that does this
  must still dim.

## The plan

1. `Expresso.Palette` calculates a dimmed color for each role of text. The dimmed color is
   the blend of the role and its background at the smallest multiple of 0.05 that keeps
   the role at 3:1 and at Lc 30. The struct gets a field `dimmed`, a map from each role to
   its dimmed color.
2. `Palette.declarations/1` writes one custom property for each dimmed color, such as
   `--text-dim` and `--code-comment-dim`.
3. The renderer writes `--dimmed: 1` next to `--dim: 1` in the rule of each `on` entity with
   the state `dim`. `--dimmed` is a registered number that inherits, so each element inside
   a dimmed element is dimmed too. An element inside the dimmed element that has its own
   `on` entity does not reset it.
4. `assets/style.css` reads each role through a mix of the role and its dimmed color:
   `color-mix(in srgb, var(--text-dim) calc(var(--dimmed, 0) * 100%), var(--text))`. The
   style sheet reads a role of text in 16 places, and the highlight rules of
   `Expresso.Highlight` read the roles of code. Each place gets the mix.
5. The filter of `[data-el]` keeps `--opacity` and the blur of an effect, and it loses the
   term of `--dim`. The transition of `--dimmed` animates the change.
6. The tests make sure that each dimmed role meets its minimums, and that the next step of
   0.05 fails. An e2e test reads the computed color of a dimmed item and of a dimmed
   comment, and it compares them with the dimmed colors of the palette.
7. The documents change: "The contrast of a theme" in `docs/architecture.md`, the table of
   `docs/reference/theme-option.md`, the state `dim` in
   `docs/reference/overlay-options.md` and the custom properties in
   `docs/reference/css-option.md`.
8. A sweep of each step of the Line 4 deck, on a dark theme and on a light theme, measures
   each dimmed text in a browser. The stills of the gallery change on the next push to
   `main`.

## The alternatives

| Alternative | Result | Why the plan does not use it |
| --- | --- | --- |
| A dimmed element shows each color of code in the color of the code text, and it dims with the opacity of the text | A dimmed line dims to 0.45 on `:default`. The CSS is one rule. | The dimmed line loses its syntax colors. |
| Lower minimums for a dimmed element | Each theme dims more. | A dimmed element must stay readable. #128 sets the minimums. |
| A blur or a lighter weight of the font | The element looks less important. | A blur makes the text less readable. A different weight changes the width of the text and moves the layout. |

## The decisions

Each decision is settled.

1. **A color for each role.** Each role gets its own dimmed color, so a dimmed line of code
   keeps its syntax colors. The alternative gives all the code of a dimmed element one
   color. It is simpler, and it loses the syntax colors.
2. **A mix in sRGB.** `Color.blend/3` calculates in sRGB, so the color of the browser
   agrees with the color that the palette measured. A mix in OKLab looks smoother, but the
   palette must then calculate in OKLab too, and the two calculations can disagree.
3. **`--dim-opacity` stays.** The plan kept it for one release, and the style sheet did
   not read it. The result changes this decision: an image, an SVG file and an embed dim
   with `--dim-opacity`, so the property stays, and it is not deprecated. "The result"
   tells why.
4. **A nested dimmed element does not dim two times.** The inherited property `--dimmed`
   carries the state to each element inside a dimmed element. A nested element with the
   state `dim` stays at the dimmed colors. The dimmed colors are the minimums, so a second
   multiplication would make the text unreadable.

## The result

The code follows the plan, with four changes:

1. **The state also reads `--dim`.** The color of a dimmed element mixes with
   `max(var(--dim, 0), var(--dimmed))`. Without a rule that reads `--dim`, the verifier of
   the properties warns that the theme does not use the state `dim`.
2. **A `dim` key of `set` also sets `--dimmed`.** `set: [dim: 0.3]` dims part of the way,
   and the renderer writes `--dimmed: 0.3` with it. The colors then move 30% of the way to
   their dimmed colors.
3. **The text of code has its own dimmed color.** A line of code takes the dimmed color of
   `--code-text`, and not of `--text`, because the background of the code is different.
   The property `--dim-color` gives the dimmed color to the element, and `.highlight`
   sets it to `--code-text-dim`.
4. **A graphic dims with one opacity.** An image, an SVG file and an embed have colors
   that the palette does not know. Also, an SVG draws with `fill` and not with
   `color`. Such a graphic inside a dimmed element dims with `filter: opacity(...)` and
   `--dim-opacity`, as before. A part of a diagram dims in the same way with its own
   state. Thus decision 3 changes, and `--dim-opacity` stays.

A rule of a deck that gives a color to text does not dim by itself. "Make a color of your
own dim" in `docs/how-to/style-one-slide.md` gives the steps for such a rule.
