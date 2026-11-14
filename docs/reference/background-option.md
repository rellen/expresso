# The background option

The `background` option gives a slide a background: an image, a color or a gradient behind
its content. The option of the deck gives the background of each slide that has no option
of its own.

```elixir
defmodule MyDeck do
  use Expresso

  background color: :code_background

  slide "title" do
    background image: "dusk.png", dim: 0.5
    heading "The evening shift"
  end
end
```

`Expresso.Builder` takes the same option, such as
`slide("title", background: [image: "dusk.png", dim: 0.5])` and
`deck(slides, background: [color: :code_background])`.

## The values

| Value | Background |
| --- | --- |
| `"dusk.png"` | The image of the file. This is the short form of `[image: "dusk.png"]`. |
| `[image: "dusk.png"]` | The image of the file. |
| `[color: :accent]` | One color. |
| `[gradient: [:accent, :background]]` | A gradient of two colors or more. |
| `:none` | No background. A slide gives it to turn off the background of the deck. |

A keyword list holds exactly one of `image`, `color` and `gradient`. It can also hold
these keys:

| Key | For | Value | Default |
| --- | --- | --- | --- |
| `fit` | An image | `:cover`: the image covers the slide, and the slide cuts the parts that do not fit. `:contain`: the slide shows the whole image. | `:cover` |
| `position` | An image | The part of the image that stays in view, or the place of an image with `fit: :contain`. One or two of `left`, `center`, `right`, `top`, `bottom` and a percentage, such as `"center top"` or `"20% 80%"`. | `"center"` |
| `angle` | A gradient | The direction of the gradient in degrees. `180` goes from the top to the bottom, and `90` goes from the left to the right. | `180` |
| `dim` | Each kind | The opacity of the dim layer, from 0 to 1. | `0` |

## The image

The path of the image is relative to the working directory of the command, or to
[the root option](root-option.md) of the deck. The file has one of the types of
[the image element](image-element.md).

The document holds the image as a data URI, so the deck stays one file. Each copy of the
slide shows the image: the present view, each page of the handout view, the overview and
the menu. The document holds a large image one time.

A screen reader does not read the image, because the background is decoration. For an
image that carries information, use [the image element](image-element.md) with an `alt`
option.

## The colors

A color of `color` and of `gradient` is one of these values:

- A role of the theme, such as `:accent`, `:background` or `:code_background`. See
  [the theme option](theme-option.md) for each role. A role follows the theme, so the
  background changes with the theme and with its variant.
- A hex color, such as `"#102030"` or `"#abc"`.

The colors of a gradient are at equal distances on its line.

## The dim layer

`dim` puts a layer in the background color of the theme over the image, the color or the
gradient. With a dark theme, the layer makes the background darker. With a light theme, it
makes the background lighter. The text of the slide then has more contrast.

`dim: 1` shows only the background color of the theme.

## The contrast of the text

The compiler does not read the image, so it gives no warning for a text with too little
contrast. [The check](check-option.md) with `--check=a11y` measures it in the browser:

- At each step of each slide with a background, the check compares the color of each text
  with the background behind the text.
- The minimum is 4.5:1, or 3:1 for large text: 24 px or more, or 18.66 px or more in
  bold. These are the minimums of WCAG 2.2, criterion 1.4.3.
- A text with less contrast is a problem with the rule `background-contrast`. The problem
  names the slide, the step and the text.
- The check does not measure a text that has a background of its own, such as a code
  element. axe-core measures such a text.

The check measures the background at a width of not more than 480 pixels. One point of
the measure is then the mean of a small area of the slide, so one bright point of a
picture does not fail a text.

## The views and paper

| Where | What shows |
| --- | --- |
| The present view, the speaker view, the overview and the menu | The background of each slide. |
| The handout view | The background behind the slide. The notes under the slide have the background color of the theme. |
| Paper | The background, with the colors of paper for the text and for the dim layer. See [the theme option](theme-option.md). |

Paper uses the default theme, which has dark text. A dark image with no dim layer then
gives dark text on a dark image. Give `dim` a value that keeps the text readable in the
two themes, or leave the slide out of the handout with [the handout option](presenter.md#the-handout-view).

## The transitions

The background is a part of its slide. The transitions `:slide` and `:zoom` move it with
the slide. With `:fade`, and with the morph, two slides with the same background show the
background with no change during the transition.

## The errors

The compiler gives an error for a value that is not one of the forms above. The message
names the key, such as:

```text
the dim of the background option must be a number from 0 to 1, such as 0.4, and not 2
```

The render stops with the path of an image file that it cannot read.

For the steps, see [Put a picture behind a slide](../how-to/put-a-picture-behind-a-slide.md).
`docs/slide-backgrounds.md` gives the reasons for the design.
