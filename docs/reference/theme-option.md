# The theme option

The `theme` option of a deck gives the colors of the slides, of the code and of the
presenter. Each built-in theme meets the contrast minimums of WCAG 2.2 and of APCA below.

```elixir
defmodule MyDeck do
  use Expresso

  name "my deck"
  theme :dracula

  slide "first" do
    heading "Hello"
  end
end
```

`Expresso.Builder` takes the same option, such as `deck(slides, theme: :dracula)`.

## The values

| Value | Colors |
| --- | --- |
| `:default` | Black text on white, with the code colors of Tango. A deck without the option gets this theme. |
| The name of a built-in theme, such as `:dracula` | That theme. The next section lists the built-in themes. |
| A map with a `#rrggbb` color for each slot from `:base00` to `:base0F` | A base16 scheme of your own. The compiler gives a warning for each color that does not meet its minimum, and the deck compiles. |
| `colors: map, adjust: true` | The map, with each color that does not meet its minimum adjusted. See [the adjustment of a map](#the-adjustment-of-a-map). |
| `dark: theme, light: theme` | Two variants. Each value is a name or a map, and `adjust: true` applies to each map. See [two variants](#two-variants). |

The compiler gives an error for a name that is not a built-in theme, and for a map with a
missing slot, an unknown slot or a color that is not `#rrggbb`. It also gives an error for
a keyword list with an unknown key, a key two times, or a form other than `colors` alone
or `dark` with `light`.

Paper always gets the default theme. A printer gives a white sheet, and a dark theme on
it wastes ink.

## The built-in themes

Each built-in theme comes from a base16 scheme of the
[Tinted Theming project](https://github.com/tinted-theming/schemes). `assets/themes/`
holds the scheme files unchanged, and `assets/themes/LICENSE` gives their MIT license.

Most schemes have colors under the minimums, frequently the color of the comments.
`Expresso.Palette.Builtin` changes the lightness of each such color until it meets its
minimum. The hue and each background stay the same. The column "Change" gives the largest
change of lightness in OKLab, from 0 to 1.

A dimmed element shows each color of its text in the dimmed color of the role. The dimmed
color is the role at the strongest dimming that keeps it at 3:1 and at Lc 30 on its
background. Thus each role dims as far as its own contrast lets it.

The column "Text dim" gives the opacity that dims the text, and the column "Comment dim"
gives the opacity that dims the comments. A lower value gives a stronger dimming. "The
contrast of a theme" in `docs/architecture.md` gives the formulas.

| Name | Theme | Variant | Change | Text dim | Comment dim |
| --- | --- | --- | --- | --- | --- |
| `:ayu_dark` | Ayu Dark | dark | 0.36 | 0.5 | 0.65 |
| `:ayu_mirage` | Ayu Mirage | dark | 0.35 | 0.55 | 0.6 |
| `:catppuccin_frappe` | Catppuccin Frappé | dark | 0.33 | 0.55 | 0.6 |
| `:catppuccin_macchiato` | Catppuccin Macchiato | dark | 0.35 | 0.5 | 0.65 |
| `:catppuccin_mocha` | Catppuccin Mocha | dark | 0.36 | 0.5 | 0.65 |
| `:default` | Default | light | 0.07 | 0.45 | 0.7 |
| `:dracula` | Dracula | dark | 0.22 | 0.45 | 0.65 |
| `:everforest` | Everforest | dark | 0.16 | 0.55 | 0.6 |
| `:everforest_dark_hard` | Everforest Dark Hard | dark | 0.15 | 0.55 | 0.6 |
| `:github` | GitHub | light | 0.11 | 0.6 | 0.8 |
| `:github_dark` | GitHub Dark | dark | 0.21 | 0.55 | 0.65 |
| `:gruvbox_dark_hard` | Gruvbox dark, hard | dark | 0.32 | 0.55 | 0.6 |
| `:gruvbox_dark_medium` | Gruvbox dark, medium | dark | 0.32 | 0.55 | 0.6 |
| `:kanagawa` | Kanagawa | dark | 0.31 | 0.5 | 0.65 |
| `:material` | Material | dark | 0.28 | 0.4 | 0.6 |
| `:monokai` | Monokai | dark | 0.25 | 0.45 | 0.6 |
| `:one_light` | One Light | light | 0.17 | 0.55 | 0.8 |
| `:rose_pine` | Rosé Pine | dark | 0.24 | 0.5 | 0.65 |
| `:rose_pine_dawn` | Rosé Pine Dawn | light | 0.20 | 0.65 | 0.8 |
| `:rose_pine_moon` | Rosé Pine Moon | dark | 0.25 | 0.5 | 0.6 |
| `:solarized_dark` | Solarized Dark | dark | 0.22 | 0.65 | 0.6 |
| `:solarized_light` | Solarized Light | light | 0.14 | 0.75 | 0.8 |
| `:tokyo_night_dark` | Tokyo Night Dark | dark | 0.35 | 0.65 | 0.65 |
| `:tokyo_night_light` | Tokyo Night Light | light | 0.27 | 0.65 | 0.75 |
| `:tokyo_night_storm` | Tokyo Night Storm | dark | 0.35 | 0.6 | 0.65 |
| `:tomorrow_night` | Tomorrow Night | dark | 0.16 | 0.55 | 0.6 |
| `:zenburn` | Zenburn | dark | 0.27 | 0.5 | 0.6 |

A dark theme needs the largest change, because most dark schemes give their comments a low
contrast. The contrast ratio of WCAG is too high for a color on a dark background, and the
APCA minimum then makes the color lighter.

### The gallery

Each picture shows the deck `examples/themes/showcase.exs` at its second step, with code,
a dimmed item, the progress bar and the slide number. `mix expresso.gifs` records one
still for each built-in theme. `docs/development.md` tells how.

| Name | Still |
| --- | --- |
| `:ayu_dark` | ![Ayu Dark, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-ayu-dark.png) |
| `:ayu_mirage` | ![Ayu Mirage, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-ayu-mirage.png) |
| `:catppuccin_frappe` | ![Catppuccin Frappé, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-catppuccin-frappe.png) |
| `:catppuccin_macchiato` | ![Catppuccin Macchiato, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-catppuccin-macchiato.png) |
| `:catppuccin_mocha` | ![Catppuccin Mocha, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-catppuccin-mocha.png) |
| `:default` | ![Default, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-default.png) |
| `:dracula` | ![Dracula, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-dracula.png) |
| `:everforest` | ![Everforest, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-everforest.png) |
| `:everforest_dark_hard` | ![Everforest Dark Hard, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-everforest-dark-hard.png) |
| `:github` | ![GitHub, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-github.png) |
| `:github_dark` | ![GitHub Dark, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-github-dark.png) |
| `:gruvbox_dark_hard` | ![Gruvbox dark, hard, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-gruvbox-dark-hard.png) |
| `:gruvbox_dark_medium` | ![Gruvbox dark, medium, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-gruvbox-dark-medium.png) |
| `:kanagawa` | ![Kanagawa, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-kanagawa.png) |
| `:material` | ![Material, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-material.png) |
| `:monokai` | ![Monokai, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-monokai.png) |
| `:one_light` | ![One Light, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-one-light.png) |
| `:rose_pine` | ![Rosé Pine, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-rose-pine.png) |
| `:rose_pine_dawn` | ![Rosé Pine Dawn, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-rose-pine-dawn.png) |
| `:rose_pine_moon` | ![Rosé Pine Moon, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-rose-pine-moon.png) |
| `:solarized_dark` | ![Solarized Dark, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-solarized-dark.png) |
| `:solarized_light` | ![Solarized Light, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-solarized-light.png) |
| `:tokyo_night_dark` | ![Tokyo Night Dark, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-tokyo-night-dark.png) |
| `:tokyo_night_light` | ![Tokyo Night Light, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-tokyo-night-light.png) |
| `:tokyo_night_storm` | ![Tokyo Night Storm, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-tokyo-night-storm.png) |
| `:tomorrow_night` | ![Tomorrow Night, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-tomorrow-night.png) |
| `:zenburn` | ![Zenburn, with code and a dimmed item](https://raw.githubusercontent.com/rellen/expresso/media/theme-zenburn.png) |

### The schemes that are not built in

A scheme is built in only when no color moves more than 0.4. A larger change gives a
color that the reader does not know as a color of the scheme. These schemes meet the
limit, and they are not built in. "Add a built-in theme" in `docs/development.md` tells
how to add one.

| Scheme | Change |
| --- | --- |
| Ayu Light | 0.26 |
| Gruvbox light, hard | 0.26 |
| Gruvbox light, medium | 0.26 |
| Catppuccin Latte | 0.29 |
| Tomorrow | 0.30 |
| Material Lighter | 0.35 |
| One Dark | 0.35 |
| Nord | 0.37 |

A map of the colors of a scheme that is not built in still works, and the compiler then
gives a warning for each color under its minimum. See [the warnings](#the-warnings).

## The minimums

| Part | WCAG 2.2 | APCA | WCAG criterion |
| --- | --- | --- | --- |
| Each text on its background: the slides, the code, the speaker view and the list of keys | 4.5:1 | Lc 60 | 1.4.3 |
| Each text of a dimmed element, in the dimmed color of its role, on its background | 3:1 | Lc 30 | 1.4.11 |
| The progress bar, the selected page of the overview and a link | 4.5:1, from the accent | Lc 60, from the accent | 1.4.11 |

Each color must meet both measures. The contrast ratio of WCAG 2.2 gives too high a value
for a color on a dark background. The lightness contrast `Lc` of APCA, the method of the
draft of WCAG 3, corrects this. Expresso uses the absolute value of `Lc`, and the
constants of APCA-W3 0.0.98G-4g.

Lc 60 is the APCA minimum for the text of content. Lc 30 is its minimum for any text that
the reader must be able to read, such as a dimmed item that the presenter does not talk
about now. WCAG lets large text have 3:1. A theme does not use the smaller minimums of large
text for its colors of text, because a projector and the light of a room lower the
contrast of each slide.

An `alert` state draws an outline, and a link has a line under its text. Thus the color
is not the only sign of these parts, as criterion 1.4.1 asks.

## The warnings

The compiler gives a warning for each role of a map that does not meet a minimum. The deck
still compiles, and the colors of the map stay as you give them. Each warning gives the
measure, the minimum, and the slot of the role with a color that passes. For the colors
of `:default` with `base03: "#dddddd"`, one warning is:

```text
the theme gives code_comment a contrast of 1.28:1, and WCAG asks for 4.5:1. The color #727272 for base03 passes
```

- The color has the hue of the slot, with a different lightness. It meets the minimums on
  each background of the roles of the slot, such as `base00` and `base01` for `base05`.
- When no lightness passes, the warning says so. Then change the color by hand, or change
  the background.
- The role `dimmed_text` stands for the role of text with the lowest contrast, at the dim
  opacity of the theme. It passes when each role of text passes.

`Expresso.Palette.suggestions/1` returns the same colors, and `Expresso.Palette.problems/1`
returns each role that fails. For the steps, see
[Use colors of your own](../how-to/use-colors-of-your-own.md).

A warning of a variant names it, such as `the dark theme gives code_comment a contrast of
...`. A built-in variant gets no warning, because it meets each minimum.

## The adjustment of a map

`adjust: true` changes the lightness of each role of a map that does not meet its minimum,
as `Expresso.Palette.Builtin` does for a built-in theme. The hue of each color and each
background stays the same. The map in the deck stays as you write it, and the document
gets the adjusted colors.

| Case | Result |
| --- | --- |
| Each role meets its minimum after the adjustment | No warning. |
| A color moves more than 0.4 in lightness | A warning, because the color can then look different from the color of the map. A built-in theme with such a change is refused. |
| No lightness gives a role its minimum, such as on a gray background | The map keeps its colors, and the compiler gives the warnings of a map with no adjustment. |

## Two variants

`theme dark: :dracula, light: :default` gives the document a dark variant and a light
variant:

| Screen or action | Variant |
| --- | --- |
| A screen with no preference, or with a light scheme | The light variant. |
| A screen with a dark scheme, as `prefers-color-scheme: dark` gives | The dark variant. |
| The key `t` in the present view | The other variant. It wins over the scheme of the screen until the next load of the document. |
| Paper | The default theme, as for one theme. |

The key `t` changes the variant of its own window only. In the speaker view, the key does
nothing, so press it in the window of the audience. A deck with one variant ignores the
key. For the steps, see
[Give a deck a light and a dark variant](../how-to/give-a-deck-two-variants.md).

## The roles

The renderer writes a custom property for each role of the theme on `:root`. The `css`
option of the deck comes after them, so a deck can replace a role.

| Property | Slot | Use |
| --- | --- | --- |
| `--background` | `base00` | The page |
| `--text` | `base05` | The text |
| `--muted` | `base04` | The slide numbers |
| `--accent` | `base0D` | The links, the progress bar and the selected page of the overview |
| `--warning` | `base09` | A talk that is behind its pace |
| `--danger` | `base08` | A talk that is over its time |
| `--code-background` | `base01` | A code block |
| `--code-text` | `base05` | Operators, variables and punctuation |
| `--code-comment` | `base03` | Comments and documentation |
| `--code-tag` | `base08` | Tags, errors and deleted lines |
| `--code-number` | `base09` | Numbers, constants and attributes |
| `--code-type` | `base0A` | Types, classes and modules |
| `--code-string` | `base0B` | Strings and inserted lines |
| `--code-support` | `base0C` | Built-ins, atoms, escapes and regular expressions |
| `--code-function` | `base0D` | Functions and headings |
| `--code-keyword` | `base0E` | Keywords |
| `--text-dim`, `--code-comment-dim` and one for each other role of text | – | The dimmed color of the role |
| `--dim-opacity` | – | The opacity of a dimmed image, SVG file and embed |

No role uses `base02`, `base06`, `base07` or `base0F`. A variable keeps the color of the
text, so a slide of code has fewer colors than an editor.

The properties of [the css option](css-option.md), such as `--progress-color` and
`--goto-color`, replace the color of one part only.
