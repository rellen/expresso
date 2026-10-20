# expresso

Declarative slide deck DSL and presenter in Elixir.

Expresso makes one HTML document from a deck. The document holds each slide, the styles and
a small script. Open the document in a browser, and present from there.

## Status

Expresso is at an early stage. It has 27 built-in themes and these elements: `text_box`,
`text_area`, `image`, `list`, `table`, `quotation`, `spacer`, `code`, `columns`, `math`,
`diagram`, `embed`, `video`, `audio`, `qr_code`, `footnote`, `shape`, `chart`, `tree`,
`callout`, `toc`, `stat` and `icon`.

Overlays are the steps inside one slide. A slide takes steps, and an element shows at a set
of steps. The document also holds a handout view for a printer. `docs/overlays.md` gives
the design.

## Install

Expresso needs Erlang/OTP 29, Elixir 1.20 and Node 24. The file `.tool-versions` gives the
exact versions. The Nix shell of the repository has each tool:

```sh
nix develop      # or: direnv allow, after you copy .envrc.example to .envrc
mix deps.get
```

Without Nix, `docs/development.md` tells how to get the same versions.

## Quick start

Write a deck in `my_deck.exs`:

```elixir
defmodule MyDeck do
  use Expresso

  name "my deck"

  slide do
    heading "Hello"

    list do
      reveal true
      item "Each item is one step"
      item "Press j for the next step"
    end
  end
end
```

Render it, and open `my_deck.html` in a browser:

```sh
mix expresso my_deck.exs my_deck.html
```

![Three steps forward, one step back, a black screen, and the last slide](https://raw.githubusercontent.com/rellen/expresso/media/present-keys.gif)

Two more options help while you write a deck:

```sh
mix expresso my_deck.exs --watch   # serve the deck, and reload it after each change
mix expresso my_deck.exs --check   # check the deck, and write a report
```

`mix expresso --help` shows each option. The page of
[the mix task](https://rellen.github.io/expresso/Mix.Tasks.Expresso.html) gives the same
text. [Make your first deck](docs/tutorials/make-your-first-deck.md) takes you through
each step.

## Documents

https://rellen.github.io/expresso/ shows the documents and the API. The documents have
four types:

- **Tutorial**: [Make your first deck](docs/tutorials/make-your-first-deck.md) teaches the
  basics in one session.
- **How-to guides** in `docs/how-to/` give the steps of one task, such as
  [Present a deck](docs/how-to/present-a-deck.md),
  [Animate elements in a slide](docs/how-to/animate-elements.md) and
  [Show data in a chart](docs/how-to/show-data-in-a-chart.md).
- **Reference** pages in `docs/reference/` describe each element and each option, with
  [the deck options](docs/reference/deck-options.md) and
  [the presenter](docs/reference/presenter.md), which gives each key.
- **Explanation**: [`docs/architecture.md`](docs/architecture.md) tells how the code
  makes a document, and [`docs/overlays.md`](docs/overlays.md) gives the design of the
  steps inside a slide.

## Develop

`mix check` runs each check: the compiler, the formatter, Credo, Dialyzer, Sobelow, the
tests, the browser tests, the binary and its tests. `docs/development.md` tells how to get
the toolchain, run each check and make a binary. `CLAUDE.md` gives the conventions for a
commit message and for prose.

## License

Apache License 2.0. See `LICENSE`.

The built-in theme uses Atkinson Hyperlegible, Copyright 2020 Braille Institute of
America, Inc. That font is under the SIL Open Font License, Version 1.1, and
`assets/fonts/OFL.txt` holds the license. Each document that Expresso makes holds the
bytes of the font, so the document needs no network.

Expresso holds the Lucide icons, Copyright Lucide Icons and Contributors, under the ISC
license. The icons that come from Feather are Copyright Cole Bemis, under the MIT license.
`priv/icons/LICENSE` holds the two licenses. A document holds the SVG of each icon that
its deck uses.
