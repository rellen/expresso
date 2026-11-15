# The description and author options

The `description` option and the `author` option of a deck give a search engine a summary
of the deck and the name of its author. Each option writes one `meta` element into the
`head` of the document.

```elixir
defmodule MyDeck do
  use Expresso

  name "Supervision trees in practice"
  description "How a supervision tree starts a process again after a failure, in ten slides."
  author "Ada Lovelace"

  slide do
    heading "Supervision trees in practice"
  end
end
```

`Expresso.Builder` takes the same options, such as
`deck(slides, description: "How a supervision tree starts a process again.")`.

## The options

| Option | Value | Tag in the document |
| --- | --- | --- |
| `description` | A text of one or two sentences | `<meta name="description" content="...">`. A search engine shows the text under the title of the deck. |
| `author` | A text | `<meta name="author" content="...">` |

- A deck with no option has no such tag. The render makes no description from the slides.
- A text of more than one line goes on one line, with one space in place of each line
  break.
- An empty text gives no tag.
- A search engine shows approximately 155 characters of a description.

## The tags of each document

Each document has these tags, with no option:

| Tag | Value | Use |
| --- | --- | --- |
| `meta charset` | `utf-8` | The encoding of the document. |
| `title` | [The name of the deck](deck-options.md), or the first heading | The name of the tab, and the title of a search result. |
| `meta name="generator"` | `Expresso` and its version, such as `Expresso 0.1.0` | The tool that made the document. |
| `meta name="color-scheme"` | `light`, `dark`, or `light dark` for a theme with two variants | The scroll bars and the colors of the system agree with [the theme](theme-option.md). |
| `meta name="theme-color"` | The background color of the theme | A browser on a phone can give its bar this color. A theme with two variants has one tag for each scheme of the screen. |

The document has no viewport tag, no Open Graph tag and no address of a network.
`docs/document-tags.md` in the repository gives the reason for each tag.

For the steps, see
[Give the deck a description](../how-to/put-a-deck-on-a-web-host.md#give-the-deck-a-description).
