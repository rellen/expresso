# The theme option

The `theme` option of a deck gives the colors of the slides, of the code and of the
presenter. Each built-in theme meets the contrast minimums of WCAG 2.2 below.

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

The compiler gives an error for a name that is not a built-in theme, and for a map with a
missing slot, an unknown slot or a color that is not `#rrggbb`.

Paper always gets the default theme. A printer gives a white sheet, and a dark theme on
it wastes ink.

## The built-in themes

Each built-in theme comes from a base16 scheme of the
[Tinted Theming project](https://github.com/tinted-theming/schemes). `assets/themes/`
holds the scheme files unchanged, and `assets/themes/LICENSE` gives their MIT license.

Most schemes have colors under the minimums, frequently the color of the comments.
`Expresso.Palette.Builtin` changes the lightness of each such color until it meets its
minimum. The hue and each background stay the same. The column "Change" gives the largest
change of lightness in OKLab, from 0 to 1. The column "Dim" gives the opacity of a dimmed
element. It is the strongest dimming that keeps each color of text at 3:1 on its
background. This includes each color of code, such as the color of a comment. The weakest
color of a built-in theme is near 4.5:1, so the theme dims to a value from 0.7 to 0.8.

| Name | Theme | Variant | Change | Dim |
| --- | --- | --- | --- | --- |
| `:ayu_dark` | Ayu Dark | dark | 0.19 | 0.75 |
| `:ayu_mirage` | Ayu Mirage | dark | 0.22 | 0.75 |
| `:catppuccin_frappe` | Catppuccin Frappé | dark | 0.21 | 0.75 |
| `:catppuccin_macchiato` | Catppuccin Macchiato | dark | 0.20 | 0.75 |
| `:catppuccin_mocha` | Catppuccin Mocha | dark | 0.20 | 0.75 |
| `:default` | Default | light | 0.07 | 0.8 |
| `:dracula` | Dracula | dark | 0.07 | 0.75 |
| `:everforest` | Everforest | dark | 0.08 | 0.75 |
| `:everforest_dark_hard` | Everforest Dark Hard | dark | 0.05 | 0.75 |
| `:github` | GitHub | light | 0.11 | 0.8 |
| `:github_dark` | GitHub Dark | dark | 0.04 | 0.75 |
| `:gruvbox_dark_hard` | Gruvbox dark, hard | dark | 0.23 | 0.75 |
| `:gruvbox_dark_medium` | Gruvbox dark, medium | dark | 0.23 | 0.75 |
| `:kanagawa` | Kanagawa | dark | 0.14 | 0.75 |
| `:material` | Material | dark | 0.19 | 0.75 |
| `:monokai` | Monokai | dark | 0.16 | 0.75 |
| `:one_light` | One Light | light | 0.17 | 0.8 |
| `:rose_pine` | Rosé Pine | dark | 0.09 | 0.75 |
| `:rose_pine_dawn` | Rosé Pine Dawn | light | 0.20 | 0.8 |
| `:rose_pine_moon` | Rosé Pine Moon | dark | 0.12 | 0.75 |
| `:solarized_dark` | Solarized Dark | dark | 0.12 | 0.8 |
| `:solarized_light` | Solarized Light | light | 0.14 | 0.8 |
| `:tokyo_night_dark` | Tokyo Night Dark | dark | 0.18 | 0.75 |
| `:tokyo_night_light` | Tokyo Night Light | light | 0.23 | 0.8 |
| `:tokyo_night_storm` | Tokyo Night Storm | dark | 0.18 | 0.75 |
| `:tomorrow_night` | Tomorrow Night | dark | 0.04 | 0.75 |
| `:zenburn` | Zenburn | dark | 0.20 | 0.7 |

A light theme dims less, because each color must stay at 3:1 on a light background.

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

A scheme is built in only when no color moves more than 0.25. A larger change gives a
color that the reader does not know as a color of the scheme. These schemes need more:

| Scheme | Change |
| --- | --- |
| One Dark | 0.26 |
| Ayu Light | 0.26 |
| Gruvbox light, hard | 0.26 |
| Gruvbox light, medium | 0.26 |
| Catppuccin Latte | 0.29 |
| Nord | 0.30 |
| Tomorrow | 0.30 |
| Material Lighter | 0.35 |

A map of the colors of such a scheme still works, and the compiler then gives a warning
for each color under its minimum.

## The minimums

| Part | Minimum | WCAG 2.2 |
| --- | --- | --- |
| Each text on its background: the slides, the code, the speaker view and the list of keys | 4.5:1 | 1.4.3 |
| Each text of a dimmed element, with the dim opacity of the theme, on its background | 3:1 | 1.4.11 |
| The progress bar, the selected page of the overview and a link | 4.5:1, from the accent | 1.4.11 |

WCAG lets large text have 3:1. A theme does not use that minimum, because a projector and
the light of a room lower the contrast of each slide.

An `alert` state draws an outline, and a link has a line under its text. Thus the color
is not the only sign of these parts, as criterion 1.4.1 asks.

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
| `--dim-opacity` | – | The opacity of a dimmed element |

No role uses `base02`, `base06`, `base07` or `base0F`. A variable keeps the color of the
text, so a slide of code has fewer colors than an editor.

The properties of [the css option](css-option.md), such as `--progress-color` and
`--goto-color`, replace the color of one part only.
