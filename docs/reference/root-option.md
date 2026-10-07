# The root option

The `root` option of a deck gives the directory of each relative path of the deck. Without
it, a relative path starts from the working directory of the command.

```elixir
defmodule MyTalk.Deck do
  use Expresso

  root Path.expand("..", __DIR__)

  slide "the server" do
    code "elixir" do
      src "lib/my_app/server.ex"
    end
  end
end
```

`Expresso.Builder` takes the same option, such as `deck(slides, root: "talk")`. For the
steps, see [Render a deck in your project](../how-to/render-a-deck-in-your-project.md).

## The values

| Value | Directory |
| --- | --- |
| `__DIR__` | The directory of the deck file. |
| `Path.expand("..", __DIR__)` | The directory above the deck file, such as the root of a project with the deck in `talk/`. |
| A relative path, such as `"talk"` | That directory, from the working directory of the command. |
| An absolute path | That directory. |

In a deck file, `__DIR__` is the directory of the file, because `mix expresso` and the
binary evaluate the file with `Code.eval_file/1`. In a deck from the standard input, such as
`cat deck.exs | mix expresso - -`, `__DIR__` is `"."`, so `root __DIR__` gives the working
directory.

## The paths that it changes

| Path | Option |
| --- | --- |
| An image | The first argument of `image`. |
| A diagram | The first argument of `diagram`. |
| A code file | The `src` option of `code`. |
| A local page | The first argument of `embed`, when it is not an address. |
| The image of an embed | The `fallback` option of `embed`. |
| A style sheet | The `css` option of the deck, when it is a path. |
| A file of `url()` | A `url()` of a style sheet in the `css` option itself. A `url()` of a CSS file starts from the directory of that file. See [the css option](css-option.md#files-in-the-style-sheet). |

These paths stay as they are:

- an absolute path, such as `"/home/me/logo.png"`,
- the address of an embed, such as `"https://example.com/"`,
- a path that the deck joins itself, such as `Path.join(@dir, "logo.png")`, when the result
  is absolute.

## The errors

The compiler gives an error for a code file that it cannot read, with the full path from the
root. The renderer raises an `ArgumentError` for an image, a diagram, a page, a style sheet
or a file of `url()` that it cannot read, with the full path.

The watch mode watches each file at its full path, so a change to a file of the project
renders the deck again.
