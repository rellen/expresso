# The external option

The `external` option keeps the file of an element next to the document, in place of a
data URI in the document. The option of the deck gives the default of each `image`,
`video` and `audio` element, and the option of an element replaces that default.

```elixir
defmodule MyDeck do
  use Expresso

  external true

  slide "the team" do
    image "team.jpg", alt: "The team in front of the office"

    image "logo.png" do
      alt "The logo of the project"
      external false
    end
  end
end
```

`Expresso.Builder` takes the same options, such as `deck(slides, external: true)` and
`image("team.jpg", alt: "The team", external: true)`.

## The values

| Where | Value | Effect |
| --- | --- | --- |
| The deck | No option, or `external false` | Each file goes into the document, so the deck is one file. This is the default. |
| The deck | `external true` | The file of each `image`, `video` and `audio` element stays next to the document. |
| An element | `external true` | The file of this element stays next to the document. |
| An element | `external false` | The file of this element goes into the document, also in a deck with `external true`. |

## The elements

| Element | With `external true` |
| --- | --- |
| [The image element](image-element.md) | The `img` element holds the address of the copy, and it has `loading="lazy"`. The browser asks for the images of the first slide at the load, and for each other image when it is idle. See [When the browser gets the file](image-element.md#when-the-browser-gets-the-file). |
| [The video element](video-element.md) | The browser asks for the file when the video plays first. The poster and the captions stay in the document. |
| [The audio element](audio-element.md) | The browser asks for the file when the sound plays first. |

These files stay in the document, also in a deck with `external true`:

- the image of [the background option](background-option.md),
- the image of a node of a `tree` element,
- the fallback image of an `embed` element,
- a file of [the css option](css-option.md),
- a font and an icon.

## The directory

The render writes a copy of each file into a directory next to the output file:

| Output file | Directory of the copies | Address in the document |
| --- | --- | --- |
| `talk.html` | `talk_files/` | `talk_files/team-3f2a1c9e.jpg` |
| `out/my talk.html` | `out/my talk_files/` | `my%20talk_files/team-3f2a1c9e.jpg` |

- The name of a copy holds the name of the file and eight digits of the SHA-256 of its
  content. A changed file gets a new name, so a web host can keep a copy in its cache for
  a long time.
- Two elements with the same file share one copy.
- Send the directory with the document. A document with no copy shows the `alt` text of
  an image and the poster of a video.
- The render does not remove an old copy from the directory.

The watch mode, `--check`, `--pdf` and `--png` work with such a deck. See
[A file next to the document](video-element.md#a-file-next-to-the-document).

## The error

The output must be a file. With `-`, the standard output, the document has no directory
for the copies, and the renderer raises an `ArgumentError` that names the first file:

```text
the image "team.jpg" has external true, so the render must write a copy of the file next
to the document. This render has no output file, so it has no directory for the copy.
Give an output file, or remove the external option.
```

For the steps, see [Put a deck on a web host](../how-to/put-a-deck-on-a-web-host.md).
