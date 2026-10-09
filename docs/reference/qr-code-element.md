# The QR code element

The `qr_code` element shows a QR code of a text, such as the address of the slides. A
phone camera reads the code from the screen or from paper.

```elixir
slide "the slides" do
  qr_code "https://rellen.github.io/expresso/" do
    label "rellen.github.io/expresso"
    size "30%"
  end
end
```

`Expresso.Builder` takes the same options, such as
`qr_code("https://rellen.github.io/expresso/", label: "rellen.github.io/expresso")`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | A string, required | The text of the code. A phone opens an address, and it shows each other text. |
| `label` | A string | A line of text under the code. The document writes it as text, so HTML in it shows as characters. |
| `title` | A string | The name of the code for a screen reader. The default is the text of the code. |
| `size` | A CSS width, such as `"300px"` or `"25%"` | The width and the height of the code. A percentage is a part of the width of the slide. The default is `40vh`, which is 40% of the height of the slide. |
| `level` | `:l`, `:m`, `:q` or `:h` | The error correction level. A higher level makes a code with more modules, which a scanner reads when a part of the code is not clear. The default is `:m`. |
| `class` | CSS class names | See [the class option](class-option.md). |

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

The compiler gives an error for a `level` that is not in the list. The text can hold 2952
bytes at most, and a long text makes a code with small modules. Keep an address short.

## The colors

A scanner reads a dark code on a light ground best. The code thus keeps its own two colors
in each theme, and not the colors of the slide:

| Custom property | Default | Part |
| --- | --- | --- |
| `--qr-color` | `#000000` | The dark modules |
| `--qr-background` | `#ffffff` | The square behind the modules |

Set the two properties in [the css option](css-option.md) to change the colors. Keep a
strong contrast between them. A light code on a dark ground does not scan with each phone.

## The HTML

The document writes a `figure` element with the class `qr-code`. It holds an `svg` element
with `role="img"` and the `title` as its `aria-label`. The SVG holds a `rect` with the class
`qr-background` and one `path` with the class `qr-modules`. With `label`, a `figcaption`
follows the SVG.

The code has a quiet zone of four modules on each side, as the standard asks. The SVG goes
into the document, so the code needs no file and no network, and it prints.
