# The url, card, favicon and robots options

Four options of a deck give the tags for a deck on a web host: the address of the deck,
the picture of the preview of a link, the icon of the tab, and the directives for a search
engine. Each option is optional, and a deck with none of them names no address of a
network.

```elixir
defmodule MyDeck do
  use Expresso

  name "Supervision trees in practice"
  description "How a supervision tree starts a process again after a failure."
  url "https://example.com/talk/"
  card image: "card.png", alt: "The title slide of the talk"
  favicon "icon.svg"

  slide do
    heading "Supervision trees in practice"
  end
end
```

`Expresso.Builder` takes the same options, such as
`deck(slides, url: "https://example.com/talk/", card: "card.png")`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| `url` | An address that starts with `https://` or `http://` | The address of the deck on its host. The document gets `link rel="canonical"`, the Open Graph tags and `twitter:card`. |
| `card` | The path of a `.png`, `.jpg` or `.jpeg` file, or `[image: path, alt: text]` | The picture of the preview of a link. It needs the `url` option. |
| `favicon` | The path of a `.svg`, `.png` or `.ico` file | The icon of the tab of the browser. The document holds the file as a data URI. |
| `robots` | A text, such as `"noindex"` | The directives for a search engine, in `meta name="robots"`. |

A path is relative to [the root option](root-option.md) of the deck, or to the working
directory of the command.

## The tags of the url option

A chat program or a social network makes a card for a link from these tags:

| Tag | Value |
| --- | --- |
| `link rel="canonical"` | The address of the `url` option. |
| `og:url` | The same address. |
| `og:type` | `website` |
| `og:title` | The name of the deck, or its first heading. |
| `og:description` | [The description option](description-option.md) of the deck. A deck with no description has no tag. |
| `og:locale` | [The lang option](lang-option.md) with a region, such as `pt_BR` for `"pt-BR"`. A language with no region, such as `"de"`, gives no tag. |
| `twitter:card` | `summary_large_image` for a deck with the `card` option, and `summary` for a deck with none. |

X reads the Open Graph tags for the title, the text and the picture of its card.

## The picture of the card

With the `card` option, the document has these tags:

| Tag | Value |
| --- | --- |
| `og:image` | The absolute address of a copy of the file, such as `https://example.com/talk/talk_files/card-3f2a1c9e.png`. |
| `og:image:type` | `image/png` or `image/jpeg`. |
| `og:image:width` and `og:image:height` | The size of the picture in pixels, from the header of the file. |
| `og:image:alt` | The `alt` text. A card with no `alt` has no tag. |

- A program that makes a card gets the picture from an address, so the picture cannot be
  a data URI. The render writes a copy of the file into the directory next to the
  document, as it does for an element with [the external option](external-option.md).
  Send that directory to the host with the document.
- The address of the picture is relative to the address of the deck, as in a browser. End
  the address of a directory with `/`. `https://example.com/talk/` gives
  `https://example.com/talk/talk_files/...`, and `https://example.com/talk` gives
  `https://example.com/talk_files/...`.
- A card usually shows a picture of 1200 by 630 pixels. The render takes a picture of each
  size, and the program cuts a picture with a different form.
- The render does not make the picture. The export option `--card card.png` makes it: a
  PNG file of 1200 by 630 pixels from slide 1, or from the slide of `--card-slide`. See
  [The export options](export-options.md#the-options-of-the-card).
- The `card` option can name the file of `--card`. The export makes the picture before it
  renders the document, so the file can be missing, and the document holds the new
  picture. See
  [Give a link to the deck a preview](../how-to/put-a-deck-on-a-web-host.md#give-a-link-to-the-deck-a-preview).

## The icon and the directives

- With no `favicon` option, the document has no icon, and a browser asks the host for
  `/favicon.ico`.
- `robots "noindex"` asks a search engine to leave the deck out of its results. A host can
  also send the header `X-Robots-Tag`.

## The errors

The compiler gives an error for a deck with the `card` option and no `url` option:

```text
the card option needs the url option, because og:image holds an absolute address. Give the
address of the deck, such as url "https://example.com/talk/", or remove the card option.
```

The renderer raises an `ArgumentError` for a card when the output is the standard output:

```text
the card image "card.png" needs an address, so the render must write a copy of the file
next to the document. This render has no output file, so it has no directory for the copy.
Give an output file, or remove the card option.
```

The renderer raises an `ArgumentError` for a picture that does not exist. The message
tells you to make the picture with `--card`:

```text
the card image "card.png" does not exist. Make it from a slide of the deck with the
export option --card card.png. The export needs Chrome or Chromium. A path is relative to
the working directory of the command, or to the root option of the deck.
```

For a `.jpg` or a `.jpeg` file, the message gives a path that ends with `.png`, because
`--card` writes a PNG file. Give that path in the `card` option too.

The renderer also raises an `ArgumentError` for a picture or an icon that it cannot read
for a different reason, such as a directory in place of a file.
