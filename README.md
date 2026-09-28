# expresso

Declarative slide deck DSL and presenter in Elixir.

Expresso makes one HTML document from a deck. The document holds each slide, the styles and
a small script. You give the document to a browser, and you present from the browser.

## Status

Expresso is at an early stage. It has one built-in theme and these elements: `text_box`,
`text_area`, `image`, `list`, `table`, `quotation`, `spacer`, `code`, `columns`, `math` and
`diagram`.

Overlays are the steps inside one slide. A slide takes steps, and an element shows at a set
of steps. The document also holds a handout view for a printer. `docs/overlays.md` gives
the design.

## Install

Expresso needs Erlang/OTP 29, Elixir 1.20 and Node 24. The file `.tool-versions` gives the
exact versions. The repository gives a Nix shell with each tool:

```sh
nix develop      # or: direnv allow, after you copy .envrc.example to .envrc
mix deps.get
```

## Make a deck

Write a script in one of two styles, and then render it.

### With the DSL

Declare a module:

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

Some notes on this example:

- `auto_reveal` shows each element of the slide one after the other.
- `reveal` does the same for the items of a list.
- An `image` reads the file and puts the bytes into the document. The document stays one
  file. The path is relative to the working directory of the command.
- `width` takes a CSS length, such as `900px`, or a percentage of the width of the slide,
  such as `60%`.
- A slide also takes a `notes` option. The handout view shows the notes under each page of
  the slide, and the speaker view shows them too.

### With the functions

Build a deck and return it. The heading goes into the metadata:

```elixir
# my_deck.exs
Expresso.Deck.new("my deck")
|> Expresso.Deck.add_slide("first", %{heading: "Hello"}, [
  Expresso.Element.TextBox.new("A text area in a text box. Text accepts <b>HTML</b>.")
])
```

### Render the document

```sh
mix expresso my_deck.exs my_deck.html
```

The second path is optional. Without it, the task writes the HTML to the standard output.
Without the first path, the task writes the usage text. The task writes the usage text and
each error message to the standard error, and the exit status is then 1. `mix help expresso`
or `mix expresso --help` gives the help of the task. A different option, such as
`--version`, is an error. A path that starts with `-` needs a directory in front of it, such
as `./-deck.exs`. When the reader of the standard output stops, as `| head` does, the task
stops with no message, and the exit status is 0.

### The options of a deck

Write an option in the deck to apply it to each slide:

| Option | Effect |
| --- | --- |
| `transition :slide` | The kind of the move into each slide: `:fade`, `:slide`, `:zoom` or `:none`. The default is `:fade`. |
| `duration 20` | The length of the talk in minutes. The speaker view then shows the time left. |
| `progress false` | Hide the progress bar at the start. |
| `slide_numbers true` | Show the number of each slide, such as `3 / 12`. |
| `handout :last` | The pages of the handout view: `:last` or `:all`. |
| `print_notes false` | Leave the notes out of the handout view and of the print. |
| `css "deck.css"` | A style sheet, or the path of one. It applies after the theme. |
| `effect`, `speed`, `easing` | The animation of each overlay. See `docs/how-to/animate-elements.md`. |

A slide takes `transition`, `handout`, `effect`, `speed` and `easing` too. An option of a
slide replaces the option of the deck for that slide.

## Present a deck

Open the HTML document in a browser.

### The keys

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
| `f` | Put the deck in full screen, or take it out of full screen. |
| `o` | Show an overview of the slides. |
| `g` | Show or hide the progress bar. |
| `?` | Show the list of the keys of the view. The next key closes it. |

A presentation remote sends `Page Down` and `Page Up`, so a remote operates the deck.

![Three steps forward, one step back, a black screen, and the last slide](https://raw.githubusercontent.com/rellen/expresso/media/present-keys.gif)

### The mouse and the touch screen

A click or a tap on the right two thirds of the window goes to the next step. A click or a
tap on the left third goes to the previous step. On a touch screen, swipe left for the next
step, and swipe right for the previous step. A click on a link goes to the link.

### The overview

The overview shows each slide at its last step, in a grid that fits the window. The arrow
keys, `j`, `k`, `Home` and `End` select a different slide. `Enter` or a click on a slide
goes to step 1 of that slide. `o` or `Esc` closes the overview, and the step does not
change. In the speaker view, only the speaker window shows the overview.

![The overview opens, the selection moves two slides, and Enter goes to that slide](https://raw.githubusercontent.com/rellen/expresso/media/present-overview.gif)

### The transitions

A change of slide in the present view fades the old slide out and the new slide in. The
`transition` option of the deck or of a slide changes the kind. A move back plays the same
kind in reverse. A change of the step keeps the animations of the overlays.

![The second slide pushes the first slide out to the left, and a move back brings it in](https://raw.githubusercontent.com/rellen/expresso/media/transition-slide.gif)

The transitions need the View Transitions API of the browser. A browser without it, and a
reader who asks for reduced motion, get an instant change. The speaker view has no
transitions.

### The address

The address of the document holds the slide and the step. For example, `deck.html#4.2` is
step 2 of slide 4. A reload shows the same step, and a link can go to one slide.

### The speaker view

The speaker view shows the current step, the next step, the notes of the slide, the
position and a timer. Put this window on your screen, and put the first window on the
projector. The keys operate in either window, and the two windows show the same step. `b`
in the speaker view gives a black screen to the audience.

![The speaker view: the current step, the next step, the notes, the position, the timer and the time left](https://raw.githubusercontent.com/rellen/expresso/media/present-speaker.png)

The timer starts at the first change of the step, and `r` sets it back to `0:00`. A
browser can block the second window. Then let the document open windows.

### The time of the talk

Write `duration 20` in the deck to give the talk a length of 20 minutes. The speaker view
then shows the time left under the timer. The time left turns amber when you are more than
one minute behind, and red after the end of the time.

Each step gets the same part of the time. You are behind when the time used is longer than
the part of the time for the steps before the current step.

The address parameter `?duration=15` replaces the deck option, so one file can give talks
of different lengths.

![The timer runs, the time left turns amber behind the pace, and red after the end](https://raw.githubusercontent.com/rellen/expresso/media/present-pace.gif)

### The progress bar

A thin bar at the bottom of the present view shows the part of the deck that is done. Each
step of each slide counts one time. Write `progress false` in the deck to hide the bar at
the start. The key `g` can still show it.

![The bar at the bottom grows with each step](https://raw.githubusercontent.com/rellen/expresso/media/present-progress.gif)

### The slide numbers

Write `slide_numbers true` in the deck to show the slide numbers. The right corner at the
bottom then shows the number of the slide and the number of slides, such as `3 / 12`.
Slide 1 shows no number, because it is usually the title slide. The handout view and the
print show the numbers too.

![Slide 3 of 6, with the number in the right corner at the bottom](https://raw.githubusercontent.com/rellen/expresso/media/present-slide-numbers.png)

### The handout view

The handout view shows one page for each step of each slide. In this view, only `j`, `k`,
`p`, `a` and `?` operate, so the other keys scroll the pages. A printer gets this view
without the key.

![The handout view: three pages, one for each step, with the notes under each page](https://raw.githubusercontent.com/rellen/expresso/media/present-handout.png)

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

### The print

To print every step, press `p` for the handout view, then `a`. The handout view then shows
each step of each slide, whatever the `handout` options select. A print or a PDF from that
window gets the same pages. Press `a` again for the selection.

`?all` at the end of the address, such as `deck.html?all`, gives the same result with no
key. A browser with no window can then make the PDF:

```sh
chromium --headless --print-to-pdf=deck.pdf "file:///path/to/deck.html?all"
```

The name of the command can be `google-chrome` or `chrome`. Without `?all`, the PDF gets
the pages that the `handout` options select.

### The custom properties of a theme

A theme can set these custom properties:

| Property | Effect |
| --- | --- |
| `--transition-dur` | The length of a transition. |
| `--pace-behind-color`, `--pace-over-color` | The colors of the time left. |
| `--progress-color`, `--progress-height` | The color and the height of the progress bar. |
| `--slide-number-color`, `--slide-number-size` | The color and the size of the slide number. |
| `--slide-number-right`, `--slide-number-bottom` | The position of the slide number. |

## Make a binary

Burrito makes a binary for macOS and for Linux, on x86_64 and on aarch64:

```sh
mix release expresso_cli_app
```

The binary takes the same two paths as the mix task. It gives the exit status 0 when it
writes the HTML, and 1 for an error. Without the first path, it writes its usage text with
the file name of the binary, such as `Usage: expresso_cli_app_linux_x86 <input> [output]`.
It writes the usage text and each error message to the standard error. With `--help` or
`-h`, it writes a help text to the standard output, and the exit status is 0. A different
option is an error, and a closed standard output gives the exit status 0, as for the mix
task.

This command needs Zig 0.16.0 and `xz` on the path. The Nix shell gives both, and the hook
of a remote Claude Code session gives both.

The first run of a binary installs its release on the computer, in a directory that has
the version of the release. A later binary of the same version runs that installed release,
and not its own. Therefore change the version in `mix.exs` for each binary that you give
to other persons. `<binary> maintenance uninstall` removes the installed release.

## Develop

```sh
mix check      # the compiler, the formatter, Credo, Dialyzer, Sobelow, the tests,
               # the browser tests, the binary and its tests
mix test
mix format
npm run check  # the types of the presenter script
npm test       # the tests of the presenter script
```

`.github/workflows/check.yml` runs the same checks for a pull request, in parallel jobs.

`CLAUDE.md` gives the conventions for a commit message and for prose.
`docs/development.md` gives more detail, and it tells you how to get a toolchain in a
container that has no Nix.

## Documents

`mix docs` makes the documentation with ExDoc, and https://rellen.github.io/expresso/
shows the result of the last push to `main`. ExDoc groups the documents by their type.

How-to guides give the steps of one task, with the code of a deck and a recording of it:

- [Add transitions between slides](docs/how-to/add-transitions.md)
- [Animate elements in a slide](docs/how-to/animate-elements.md)

Reference pages describe each value of an option:

- [The transition option](docs/reference/transition-option.md)
- [The overlay options](docs/reference/overlay-options.md)
- [The css option](docs/reference/css-option.md)

Explanations give the design and its reasons:

- `docs/architecture.md` — how the code makes an HTML document from a deck.
- `docs/overlays.md` — the design for overlays, which are the steps inside one slide.

For a contributor:

- `docs/development.md` — the toolchain, the checks and a browser.
- `docs/typescript.md` — the plan for the presenter script in TypeScript.

## License

Apache License 2.0. See `LICENSE`.

The built-in theme uses Atkinson Hyperlegible, Copyright 2020 Braille Institute of
America, Inc. That font is under the SIL Open Font License, Version 1.1, and
`assets/fonts/OFL.txt` holds the license. Each document that Expresso makes holds the
bytes of the font, so the document needs no network.
