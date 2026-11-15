# The image element

The `image` element shows an image file. The document holds the file as a data URI, so the
deck stays one file. With `external true`, the file stays next to the document.

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
| `external` | `true` or `false` | Keep the file next to the document, in place of a data URI in the document. The default is the `external` option of the deck, or `false`. See "A file next to the document". |
| `goto` | A slide and a step, such as `[slide: 5]` or `[slide: "summary"]` | Makes the element a link to that slide and step. See [the goto option](goto-option.md). |
| `window` | `:macos`, `:terminal`, `:plain` or `:none` | A frame that looks like a window. The default is the `window` option of the deck. See [the window option](window-option.md). |
| `window_title` | A string | The text of the bar of the window. |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

The render gives an error for a file that it cannot read, and for an extension that is not
in the list.

## A file next to the document

With `external true`, the document does not hold the image file. The render writes a copy
of the file into a directory next to the output file, such as `talk_files/` for
`talk.html`, and each `img` element holds the relative address of the copy, such as
`talk_files/team-3f2a1c9e.jpg`.

```elixir
slide "the team" do
  image "team.jpg" do
    alt "The team in front of the office"
    external true
  end
end
```

- The document is smaller. A photograph of 500 KB adds approximately 670 KB to a document
  as a data URI, and 60 bytes as an address.
- A web host can keep the copy in its cache. A change of the text of the deck then does
  not send the image again.
- The browser asks for each image when it loads the document, also for an image of a
  later slide. An image thus shows at its step with no wait.
- Two elements with the same file share one copy.
- The output must be a file. With `-`, the standard output, the renderer raises an
  `ArgumentError` that names the image and the option.
- Send the directory with the document. A document with no copy shows the `alt` text.

[The external option](external-option.md) gives the option of the deck, the directory and
the error.

## The width

| `width` | The image |
| --- | --- |
| None | The image takes its natural size. The theme makes it smaller when the slide is too small. |
| A length, such as `"900px"` | The image takes that width. In a window that is smaller than 1280 by 720 pixels, the width becomes smaller with the slide. See [The size of a slide](slide-size.md). |
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
