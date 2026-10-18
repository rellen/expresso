# The dim_contrast option

The `dim_contrast` option of a deck gives the minimum contrast ratio of dimmed text on its
background. Give `4.5` to meet criterion 1.4.3 of WCAG 2.2 for normal text.

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
theme, then has almost no dimming at 4.5. The focus of the `highlight` option of a code
element still shows, because the lines in focus get a bar in the color `--accent`.

## When to give it

The default of 3:1 keeps a clear difference between the text in focus and the dimmed text.
On a slide, the text is usually large. Give `dim_contrast 4.5` when:

- the deck has dimmed text under 24 px, such as a long code listing at a small size, or
- a checker such as axe-core must find no violation.

## The errors

The compiler gives an error for a value that is not a number from 3 to 7.

For the steps, see
[Keep dimmed text readable](../how-to/make-a-deck-accessible.md#keep-dimmed-text-readable).
`docs/architecture.md` gives the formulas of the dimming.
