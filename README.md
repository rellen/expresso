# expresso

Declarative slide deck DSL and presenter in Elixir.

Expresso makes one HTML document from a deck. The document holds each slide, the styles and
a small script. You give the document to a browser, and you present from the browser.

## Status

Expresso is at an early stage. It has the elements `text_box`, `text_area`, `image` and
`list`, and one built-in theme.

Overlays are the steps inside one slide, and the code contains each part of their design.
A slide takes steps, and an element shows at a set of steps. The document also holds a
handout view for a printer. See `docs/overlays.md`.

## Install

Expresso needs Erlang/OTP 29, Elixir 1.20 and Node 24. The file `.tool-versions` gives the
exact versions.

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

  name "my deck"

  slide do
    heading "Hello"

    text_box do
      text_area do
        text "A text area in a text box. Text accepts <b>HTML</b>."
      end
    end
  end

  slide "steps" do
    auto_reveal true

    image "logo.png" do
      alt "The logo"
      width "60vw"
    end

    text_box do
      text_area do
        text "This text shows one step after the image."
      end
    end
  end

  slide "points" do
    list do
      reveal true
      item "The first point"

      item "The second point" do
        list do
          ordered true
          item "A nested item"
        end
      end
    end
  end
end
```

`auto_reveal` shows each element of the slide one after the other, and `reveal` does the
same for the items of a list. An `image` reads the
file and puts the bytes into the document, so the document stays one file. The path is
relative to the working directory of the command. The `width` option takes a CSS length,
such as `900px`, or a percentage of the width of the slide, such as `60%`.

With the functions, build a deck and return it. The heading goes into the metadata:

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
| `j` | Go to the next step, or to the next slide after the last step. |
| `k` | Go to the previous step, or to the previous slide at the first step. |
| `p` | Change between the present view and the handout view. |

The handout view shows one page for each step of each slide. A printer gets this view
without the key.

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
npm run check  # the types of the presenter script
npm test       # the tests of the presenter script
```

`.github/workflows/check.yml` runs the same commands for a pull request.

`CLAUDE.md` gives the conventions for a commit message and for prose.
`docs/development.md` gives more detail, and it tells you how to get a toolchain in a
container that has no Nix.

## Documents

- `docs/architecture.md` — how the code makes an HTML document from a deck.
- `docs/development.md` — the toolchain, the checks and a browser.
- `docs/overlays.md` — the design for overlays, which are the steps inside one slide.
- `docs/typescript.md` — the plan for the presenter script in TypeScript.

## License

Apache License 2.0. See `LICENSE`.

The built-in theme uses Atkinson Hyperlegible, Copyright 2020 Braille Institute of
America, Inc. That font is under the SIL Open Font License, Version 1.1, and
`assets/fonts/OFL.txt` holds the license. Each document that Expresso makes holds the
bytes of the font, so the document needs no network.
