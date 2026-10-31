# The dim_contrast option

The `dim_contrast` option of a deck gives the minimum contrast ratio of dimmed text on its
background. Give `4.5` to meet criterion 1.4.3 of WCAG 2.2 for normal text. At `4.5`, each
light built-in theme does not dim, and the compiler gives a warning. See
[A theme that does not dim](#a-theme-that-does-not-dim).

```elixir
defmodule MyDeck do
  use Expresso

  dim_contrast 4.5
end
```

`Expresso.Builder` takes the same option, such as `deck(slides, dim_contrast: 4.5)`.

## The values

| Value | Effect |
| --- | --- |
| No option | Each role of text dims to 3:1. This is the default. |
| A number from 3 to 7 | Each role of text dims only as far as it keeps this ratio on its background. |

| Ratio | Source |
| --- | --- |
| 3 | The minimum of WCAG 2.2 for large text, and for a part that is not text (criterion 1.4.11). |
| 4.5 | The minimum of WCAG 2.2 for normal text, criterion 1.4.3. axe-core asks for it on text under 24 px, or under 19 px in bold. |
| 7 | The enhanced minimum of WCAG 2.2 for normal text, criterion 1.4.6. |

The minimum of APCA for dimmed text stays at Lc 30 at each value.

## What it changes

The option changes each dimmed color of [the theme](theme-option.md), such as
`--text-dim` and `--code-comment-dim`, and the opacity `--dim-opacity` of a dimmed image,
SVG file, embed and video. Each variant of a theme with two variants, and the colors of paper,
follow the option.

A higher ratio dims less. A role of text near 4.5:1, such as the numbers of the default
theme, then does not dim at 4.5. The focus of the `highlight` option of a code
element still shows, because the lines in focus get a bar in the color `--accent`.

## A theme that does not dim

A theme does not dim when one role of text is near the ratio of the option. No opacity under
1.0 then keeps that role at the ratio, so `--dim-opacity` is 1.0. These are the results:

- A dimmed image, SVG file, embed and video do not dim, because the style sheet dims them
  with `--dim-opacity`.
- Each role near the ratio keeps its color in the state `dim`.
- With `:solarized_light` at 4.5, no role of text dims, so the state `dim` does nothing to text.

At 4.5, each light built-in theme has `--dim-opacity` 1.0:

| Theme | Roles of text that do not dim at 4.5 |
| --- | --- |
| `:default` | `warning`, `success`, `argument`, `code_number`, `code_string` and `code_support` |
| `:github` | `muted`, `code_comment`, `code_type` and `code_function` |
| `:one_light` | 10 of the 18 roles |
| `:rose_pine_dawn` | 14 of the 18 roles |
| `:solarized_light` | Each of the 18 roles |
| `:tokyo_night_light` | `warning` and `argument` |

At 7, 21 of the 27 built-in themes do not dim. At the default of 3, each built-in theme dims.

The compiler gives a warning for each variant of the theme that does not dim, and the deck
still compiles. `--check` gives the same text as a note. This is the warning for the default
theme at 4.5:

```text
at a dim contrast of 4.5:1, the theme gives --dim-opacity 1.0, so a dimmed image, SVG file, embed and video do not dim, and the roles warning, success, argument, code_number, code_string, code_support do not dim. Give a lower dim_contrast or a theme with more contrast. See docs/reference/dim-contrast-option.md
```

To get the dimming again, do one of these steps:

- Give a lower ratio, such as `dim_contrast 4`. Each light built-in theme dims at 4.
- Give a dark theme, such as `:dracula`, which dims at 4.5.
- Give a theme of 16 colors with more contrast for each role that the warning names.

The colors of paper use the default theme, so at 4.5 a printed page does not dim either.
The compiler gives no warning for paper.

## When to give it

The default of 3:1 keeps a clear difference between the text in focus and the dimmed text.
On a slide, the text is usually large. Give `dim_contrast 4.5` when:

- the deck has dimmed text under 24 px, such as a long code listing at a small size, or
- a checker such as axe-core must find no violation.

## The errors and the warnings

The compiler gives an error for a value that is not a number from 3 to 7. It gives a warning
for a theme that does not dim at the value. See
[A theme that does not dim](#a-theme-that-does-not-dim).

For the steps, see
[Keep dimmed text readable](../how-to/make-a-deck-accessible.md#keep-dimmed-text-readable).
`docs/architecture.md` gives the formulas of the dimming.
