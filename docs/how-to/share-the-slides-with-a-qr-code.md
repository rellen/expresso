# Share the slides with a QR code

This guide shows how to put a QR code on a slide, so that the audience can open an address
with a phone. The code is part of the document, so it needs no file and no network. For
each option, see [The QR code element](../reference/qr-code-element.md).

## Show a QR code

Write a `qr_code` element with the address as its first argument. The `label` option
writes the address under the code, for a person who cannot scan it. The `size` option
gives the width of the code as a part of the width of the slide:

```elixir
defmodule Examples.QrCode do
  use Expresso

  theme :dracula

  slide "the slides" do
    heading "The slides of this talk"

    qr_code "https://rellen.github.io/expresso/" do
      label "rellen.github.io/expresso"
      size "30%"
    end
  end
end

Examples.QrCode
```

![A QR code of the address of the slides, with the address under it](https://raw.githubusercontent.com/rellen/expresso/media/qr-code.png)

The code keeps its black and white colors in a dark theme, because a scanner reads a dark
code on a light ground best.

## Show the code at a step

A QR code takes the overlay options, as each element does. Give the code an `at` option to
show it after the other content, such as at the end of a talk:

```elixir
defmodule Examples.QrCodeAt do
  use Expresso

  slide "questions" do
    heading "Questions?"

    columns do
      column do
        list do
          item "The slides"
          item "The code of the examples"
        end
      end

      column do
        qr_code "https://rellen.github.io/expresso/" do
          at from: 2
          effect :grow
          label "Scan for the slides"
        end
      end
    end
  end
end

Examples.QrCodeAt
```

![The list shows at step 1, and the QR code grows in at step 2](https://raw.githubusercontent.com/rellen/expresso/media/qr-code-at.gif)

## Change the colors of the code

Set `--qr-color` and `--qr-background` in the `css` option of the deck. Keep the modules
darker than the ground, with a strong contrast between the two colors. The `title` option
gives the name of the code for a screen reader:

```elixir
defmodule Examples.QrCodeColors do
  use Expresso

  theme :gruvbox_dark_hard

  css """
  .qr-code {
    --qr-color: #3c3836;
    --qr-background: #fbf1c7;
  }
  """

  slide "the slides" do
    heading "The slides"

    qr_code "https://rellen.github.io/expresso/" do
      title "The address of the slides"
      size "25%"
    end
  end
end

Examples.QrCodeColors
```

![A QR code with dark gray modules on a light yellow ground](https://raw.githubusercontent.com/rellen/expresso/media/qr-code-colors.png)

Scan the code with a phone before the talk. Do this test again after a change of the
colors or of the size.
