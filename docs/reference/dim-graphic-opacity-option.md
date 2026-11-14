# The dim_graphic_opacity option

The `dim_graphic_opacity` option of a deck gives the opacity of a dimmed graphic: an image,
an SVG file, an embed and a video. Without the option, a graphic dims with the opacity that
keeps each role of text at [the dim_contrast option](dim-contrast-option.md).

```elixir
defmodule MyDeck do
  use Expresso

  dim_contrast 4.5
  dim_graphic_opacity 0.5
end
```

`Expresso.Builder` takes the same option, such as `deck(slides, dim_graphic_opacity: 0.5)`.

## The values

| Value | Effect |
| --- | --- |
| No option | A dimmed graphic gets the opacity `--dim-opacity` of the theme. This is the default. |
| A number that is more than 0 and not more than 1 | A dimmed graphic gets this opacity. `1` gives a graphic that does not dim. |

## What it changes

The option writes the custom property `--dim-graphic-opacity` for each variant of the theme
and for paper. The style sheet dims these graphics with it:

- An image, an SVG file, an embed and a video in an element with the state `dim`.
- A part of a diagram with the state `dim`.

The option does not change these parts of a slide:

- A text. Each role of text keeps its dimmed color, such as `--text-dim`.
- An icon, the icon of a callout and a line of a `shape` element. They draw with the color
  of their role, so they dim as the text does.
- A series of a chart. Its marks fade to `--chart-dim-opacity`. See
  [the chart element](chart-element.md).

## When to give it

Give the option when the theme does not dim at the `dim_contrast` of the deck. Then
`--dim-opacity` is 1.0, and a graphic does not dim. Each light built-in theme has this
result at `dim_contrast 4.5`. See
[A theme that does not dim](dim-contrast-option.md#a-theme-that-does-not-dim).

The `dim_contrast` option gives a minimum for text. The option does not measure a graphic,
and a graphic can hold text, such as a label of a diagram. Thus select an opacity at which
you can still read that text.

## The errors and the warnings

The compiler gives an error for a value that is not a number, for `0`, for a negative
number and for a number that is more than 1:

```text
the dim_graphic_opacity option must be a number that is more than 0 and not more than 1, such as 0.5, and not 0
```

With the option, the warning for a theme that does not dim names only the roles of text.

`docs/dim-state.md` gives the reasons for the design.
