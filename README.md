# expresso

Declarative slide deck DSL and presenter in Elixir.

Expresso makes one HTML document from a deck. The document holds each slide, the styles and
a small script. You give the document to a browser, and you present from the browser.

## Status

Expresso is at an early stage. It has the elements `text_box`, `text_area`, `image`,
`list`, `table`, `quotation`, `spacer`, `code`, `columns`, `math` and `diagram`, and one
built-in theme.

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
same for the items of a list. A slide also takes a `notes` option, and the handout view
shows the notes under each page of the slide. An `image` reads the
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
| `j`, `→`, `↓`, `Space`, `Page Down` | Go to the next step, or to the next slide after the last step. |
| `k`, `←`, `↑`, `Page Up` | Go to the previous step, or to the previous slide at the first step. |
| `Home` | Go to the first slide. |
| `End` | Go to step 1 of the last slide. |
| A number, then `Enter` | Go to step 1 of that slide. For example, `1` `2` `Enter` goes to slide 12. |
| `b` | Show a black screen. The next key shows the slide again. |
| `p` | Change between the present view and the handout view. |
| `s` | Open the speaker view in a second window. |
| `g` | Show or hide the progress bar. |
| `?` | Show the list of the keys of the view. The next key closes it. |

A presentation remote sends `Page Down` and `Page Up`, so a remote operates the deck.

The address of the document holds the slide and the step, for example `deck.html#4.2`
for step 2 of slide 4. A reload shows the same step, and a link can go to one slide.

The speaker view shows the current step, the next step, the notes of the slide, the
position and a timer. Put this window on your screen, and put the first window on the
projector. The keys operate in either window, and the two windows show the same step. `b`
in the speaker view gives a black screen to the audience. The timer starts at the first
change of the step, and `r` sets it back to `0:00`. A browser can block the second
window. Then let the document open windows.

A thin bar at the bottom of the present view shows the part of the deck that is done.
Each step of each slide counts one time. Write `progress false` in the deck to hide the
bar at the start. The key `g` can still show it. A theme can set `--progress-color` and
`--progress-height`.

The handout view shows one page for each step of each slide. In this view, only `j`, `k`,
`p`, `a` and `?` operate, so the other keys scroll the pages. A printer gets this view
without the key.

A slide can select the steps that get a page, with the forms of `at`:

```elixir
slide "overlays" do
  handout [3, :last]
  # ...
end
```

`handout :last` gives the last step only, and `handout :all` gives each step. `:last` can
also go in a list, such as `[2, :last]`. Write `handout :last` in the deck to give the last
step of each slide without the option. The handout view on a screen shows the same pages as
the paper. The speaker view still shows each step.

To print every step, press `p` for the handout view, then `a`. The handout view then shows
each step of each slide, whatever the `handout` options select, and a print or a PDF from
that window gets the same pages. Press `a` again for the selection.

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
