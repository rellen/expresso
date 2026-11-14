# Put a picture behind a slide

This guide shows how to give a slide a background: a picture, a color or a gradient behind
its content. It also shows how to keep the text readable on a picture.

## Give a slide a picture

Write `background` in the slide, with the path of the picture:

```elixir
defmodule Examples.Background do
  use Expresso

  name "The evening shift"
  root __DIR__
  theme :dracula

  slide "title" do
    background image: "dusk.png", dim: 0.5
    heading "The evening shift"

    text_box do
      text_area(text: "What a team does after the sun goes down")
    end
  end

  slide "part" do
    background gradient: [:accent, :background], angle: 135, dim: 0.4
    heading "Part 1: the plan"
  end

  slide "plan" do
    heading "The plan"

    list do
      item "Look at the alerts of the day"
      item "Start the long jobs"
      item "Write the notes for the morning"
    end
  end
end

Examples.Background
```

![A title on a picture of a dusk sky, then a title on a gradient, then a slide with no background](https://raw.githubusercontent.com/rellen/expresso/media/background.gif)

The picture covers the slide, and the content of the slide is in front of it. The document
holds the picture, so the deck is still one file.

`background "dusk.png"` is the short form for a picture with no other key.

## Keep the text readable

A picture has light parts and dark parts, and the text needs contrast on each part. The
key `dim` puts a layer in the background color of the theme over the picture:

```elixir
background image: "dusk.png", dim: 0.5
```

`dim` is the opacity of that layer, from 0 to 1. A dark theme makes the picture darker, and
a light theme makes it lighter. A color and a gradient take `dim` too: the gradient of the
example needs it, because its text has too little contrast on the accent color.

To find the value, do these steps:

1. Run the accessibility check:

   ```sh
   mix expresso deck.exs --check=a11y
   ```

2. Read each problem with the rule `background-contrast`. It names the slide and the text
   that has too little contrast on the picture.
3. Give `dim` a higher value, and run the check again.

See [Check a deck](check-a-deck.md) for the tools that the check needs.

## Show the whole picture

By default, the picture covers the slide, and the slide cuts the parts that do not fit. To
show the whole picture, give `fit: :contain`:

```elixir
background image: "chart.png", fit: :contain, position: "right bottom"
```

`position` tells which part of the picture stays in view, or where a picture with
`fit: :contain` goes. Give one or two of `left`, `center`, `right`, `top`, `bottom` and a
percentage.

## Give a color or a gradient

```elixir
background color: :accent
background color: "#102030"
background gradient: [:accent, :background], angle: 135
```

A color is a role of the theme, such as `:accent`, or a hex color. A role follows the
theme, so the slide changes with the theme and with its variant. `angle` gives the
direction of the gradient in degrees: `180` goes from the top to the bottom, and `90` goes
from the left to the right.

## Give each slide the same background

Write `background` in the deck. Each slide with no `background` then gets it. A slide
turns it off with `background :none`:

```elixir
defmodule MyDeck do
  use Expresso

  background color: :code_background

  slide "title" do
    background image: "dusk.png", dim: 0.5
    heading "The title has its own background"
  end

  slide "plain" do
    background :none
    heading "This slide has no background"
  end
end
```

See [the background option](../reference/background-option.md) for each key and each
rule.
