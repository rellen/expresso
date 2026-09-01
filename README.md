# expresso

Declarative slide deck DSL and presenter in Elixir.

Expresso makes one HTML document from a deck. The document holds each slide, the styles and
a small script. You give the document to a browser, and you present from the browser.

## Status

Expresso is at an early stage. It has two elements, `text_box` and `text_area`, and one
built-in theme. Overlays, which are the steps inside one slide, are a design only. See
`docs/overlays.md`.

## Install

Expresso needs Erlang 28, Elixir 1.20 and Node 24. The file `.tool-versions` gives the exact
versions.

The repository gives a Nix shell with each tool:

```sh
nix develop      # or: direnv allow, after you copy .envrc.example to .envrc
mix deps.get
```

## Make a deck

Write a script in one of two styles.

With the DSL, declare a module:

```elixir
# my_deck.exs
defmodule MyDeck do
  use Expresso

  name("my deck")

  slide do
    text_box do
      text_area do
        text "A text area in a text box. Text accepts <b>HTML</b>."
      end
    end
  end
end
```

With the functions, build a deck and return it. This style also gives a heading to a slide:

```elixir
# my_deck.exs
Expresso.Deck.new("my deck")
|> Expresso.Deck.add_slide("first", %{heading: "Hello"}, [
  Expresso.Element.TextBox.new("A text area in a text box. Text accepts <b>HTML</b>.")
])
```

Then make the HTML document:

```sh
mix expresso my_deck.exs my_deck.html
```

The second path is optional. Without it, the task writes the HTML to the standard output.
Without the first path, the task writes the usage text.

## Present a deck

Open the HTML document in a browser. The keys are:

| Key | Action |
| --- | --- |
| `j` | Go to the next slide. |
| `k` | Go to the previous slide. |
| `p` | Show all the slides, for a printer. |

## Make a binary

Burrito makes a binary for macOS and for Linux, on x86_64 and on aarch64:

```sh
mix release expresso_cli_app
```

The binary takes the same two paths as the mix task.

This command needs Zig 0.16.0 and `xz` on the path. The Nix shell gives both. A container of
a remote Claude Code session has `xz`, but it has no Zig, and the command gives an error.

## Develop

```sh
mix check      # the compiler, the formatter, Credo, Dialyzer, Sobelow and the tests
mix test
mix format
```

`CLAUDE.md` gives the conventions for a commit message and for prose.
`docs/development.md` gives more detail, and it tells you how to get a toolchain in a
container that has no Nix.

## Documents

- `docs/architecture.md` — how the code makes an HTML document from a deck.
- `docs/development.md` — the toolchain, the checks and a browser.
- `docs/overlays.md` — the design for overlays, which are the steps inside one slide.

## License

Apache License 2.0. See `LICENSE`.
