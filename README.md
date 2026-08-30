# expresso

Declarative slide deck DSL and presenter in Elixir.

Expresso makes one HTML document from a deck. The document holds each slide, the styles and
a small script. You give the document to a browser, and you present from the browser.

## Status

Expresso is at an early stage. The imperative API operates. The Spark DSL parses a deck, but
it cannot make an HTML document yet. `docs/architecture.md` gives the details.

## Install

Expresso needs Erlang 28, Elixir 1.20 and Node 24. The file `.tool-versions` gives the exact
versions.

The repository gives a Nix shell with each tool:

```sh
nix develop      # or: direnv allow, after you copy .envrc.example to .envrc
mix deps.get
```

## Make a deck

Write a script that returns an `Expresso.Deck` struct:

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

## Develop

```sh
mix check      # the compiler, the formatter, Credo, Dialyzer, Sobelow and the tests
mix test
mix format
```

`CLAUDE.md` gives the conventions for a commit message and for prose.

## Documents

- `docs/architecture.md` — how the code makes an HTML document from a deck.
- `docs/overlays.md` — the design for overlays, which are the steps inside one slide.

## License

Apache License 2.0. See `LICENSE`.
