# The image element

The `image` element shows an image file. The document holds the file as a data URI, so the
deck stays one file.

```elixir
slide "the logo" do
  image "logo.png" do
    alt "The logo of the project"
    width "40%"
  end
end
```

`Expresso.Builder` takes the same options, such as
`image("logo.png", alt: "The logo of the project", width: "40%")`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | The path of an `.avif`, `.gif`, `.jpeg`, `.jpg`, `.png`, `.svg` or `.webp` file | The image. A path is relative to [the root option](root-option.md) of the deck, or to the working directory of the command. |
| `alt` | A string | The text of the image for a screen reader. Without it, the image is decorative, and the `alt` attribute is empty. |
| `width` | A CSS width, such as `"900px"` or `"60%"` | The width of the image. A percentage is a part of the width of the slide. The default is the natural width of the image. |
| `goto` | A slide and a step, such as `[slide: 5]` or `[slide: "summary"]` | Makes the element a link to that slide and step. See [the goto option](goto-option.md). |
| `class` | CSS class names | See [the class option](class-option.md). |

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

The render gives an error for a file that it cannot read, and for an extension that is not
in the list.

## The width

| `width` | The image |
| --- | --- |
| None | The image takes its natural size. The theme makes it smaller when the slide is too small. |
| A length, such as `"900px"` | The image takes that width. |
| A percentage, such as `"60%"` | The image takes that part of the width of the slide. The document writes `60vw`. |
| A CSS function, such as `"calc(50% + 10px)"` | The value goes into the document as it is. |

The width goes into the custom property `--image-width`, in the `style` attribute of the
element. An `on` entity can set the same property, so the image can change its size at a
step:

```elixir
slide "the detail" do
  image "map.png" do
    on 2, set: ["image-width": "80vw"]
  end
end
```

Use the `on` entity only on an image with no `width` option. The `style` attribute of the
`width` option takes priority over the rule of the `on` entity, and the width then does
not change. Write a percentage of the slide as `vw` in `set`, because the `on` entity does
not change `%` to `vw`.

## SVG

An `.svg` file in an `image` is a picture: the theme cannot change its colors, and its parts
cannot show at steps. To show the parts of an SVG file at steps, use
[the diagram element](diagram-element.md).

## The watch mode

The watch mode renders the deck again after a change to the image file.
