# expresso

Declarative slide deck DSL and presenter in Elixir.

Expresso makes one HTML document from a deck. The document holds each slide, the styles and
a small script. Open the document in a browser, and present from there.

## Status

Expresso is at an early stage. It has one built-in theme and these elements: `text_box`,
`text_area`, `image`, `list`, `table`, `quotation`, `spacer`, `code`, `columns`, `math` and
`diagram`.

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
- A text area, an image or an item takes a `goto` option, such as `goto: [slide: 5]` or
  `goto: [slide: "summary"]`. The element is then a link to that slide. See
  [the goto option](docs/reference/goto-option.md).

### With the functions

`Expresso.Builder` has one function for each entity of the DSL, with the same name and the
same options. A function takes the arguments of the entity, then a keyword list with the
options and the children. Build a deck with `deck/2` and return it:

```elixir
# my_deck.exs
import Expresso.Builder

points = ["Concurrency", "Fault tolerance"]

deck(
  [
    slide("first",
      heading: "Hello",
      elements: [text_box(elements: [text_area(text: "Text accepts <b>HTML</b>.")])]
    ),
    slide("second", elements: [list(reveal: true, elements: Enum.map(points, &item/1))])
  ],
  name: "my deck"
)
```

`deck/2` runs the checks of the DSL, so an overlay and a wrong option give the same steps
and the same errors. Use the functions when a program makes the slides at runtime. A
module of the DSL can also make slides from data with `for`, but a module of many slides
compiles slowly: 2000 slides take approximately 30 seconds, and the functions take
approximately 0.1 seconds. See [Make a deck from data](docs/how-to/make-a-deck-from-data.md).

### Render the document

```sh
mix expresso my_deck.exs my_deck.html
```

- The second path is optional. Without it, the task writes the HTML to the standard output.
- `-` reads the script from the standard input, or writes the HTML to the standard output:
  `cat my_deck.exs | mix expresso - -`.
- `mix expresso --help` shows the help, and `mix expresso --version` shows the version of
  Expresso.
- The task writes each error message, and the usage text, to the standard error. The exit
  status is then 1. An unknown option, such as `--verbose`, is an error, and so is a third
  path.
- A path that starts with `-` needs a directory in front of it, such as `./-deck.exs`.
- When the reader of the output stops, as `| head` does, the task stops with no message,
  and the exit status is 0.

### Watch a deck

Add `--watch` to serve the document while you write the deck:

```sh
mix expresso my_deck.exs --watch
```

Open `http://127.0.0.1:4100/` in a browser. After each change to the deck file, or to an
image, a diagram or a style sheet of the deck, the task renders the deck again. The page
then reloads, and it shows the same step. The speaker view reloads too.

- `--port 4200` gives a different port.
- An output path, such as `my_deck.html`, also gets the document after each render.
- When a render fails, the task writes the error in the terminal, and the page keeps the
  last good document.
- Stop the task with Ctrl-C.

The binary takes the same options.

### The options of a deck

Write an option in the deck to apply it to each slide:

| Option | Effect |
| --- | --- |
| `transition :slide` | How each slide comes in: `:fade`, `:slide`, `:zoom` or `:none`. The default is `:fade`. |
| `duration 20` | The length of the talk in minutes. The speaker view then shows the time left. |
| `progress false` | Hide the progress bar at the start. |
| `slide_numbers true` | Show the number of each slide, such as `3 / 12`. |
| `handout :last` | The pages of the handout view: `:last` or `:all`. |
| `print_notes false` | Leave the notes out of the handout view and of the print. |
| `css "deck.css"` | A style sheet, or the path of one. It applies after the theme. |
| `effect`, `speed`, `easing` | The animation of each overlay. See `docs/how-to/animate-elements.md`. |
| `template MyDeckTemplate` | A module that makes the header and the footer. See [the template option](docs/reference/template-option.md). |
| `theme :dracula` | The colors of the slides and of the code. Each built-in theme meets the contrast minimums of WCAG. See [the theme option](docs/reference/theme-option.md). |

A slide takes `transition`, `handout`, `effect`, `speed`, `easing` and `template` too. An option on a
slide replaces the option of the deck for that slide.

## Present a deck

Open the HTML document in a browser.

### The keys

The present view knows these keys. `?` shows the same list in the browser.

<!-- keys present -->

| Key | Action |
| --- | --- |
| `j`, `→`, `↓`, `Page Down`, `Space` | Next step, or the first step of the next slide |
| `k`, `←`, `↑`, `Page Up` | Previous step, or the last step of the previous slide |
| `Home` | First slide |
| `End` | Step 1 of the last slide |
| 0 to 9 | Type a slide number |
| `Enter` | Step 1 of the slide that you typed |
| `b` | Black screen. The next key shows the slide again. |
| `p` | Handout view |
| `s` | Speaker view, in a second window |
| `f` | Full screen on or off |
| `g` | Progress bar on or off |
| Click or tap the right two thirds, or swipe left | Next step |
| Click or tap the left third, or swipe right | Previous step |
| Click or tap a link | The slide and the step of the link |
| `o` | Overview of the slides. Only this window shows it. |
| `?` | This list of keys. The next key closes it. |

<!-- /keys -->

To go to a slide, type its number, then press `Enter`. For example, `1` `2` `Enter` goes
to slide 12. The number shows in the top right corner until `Enter`.

A presentation remote sends `Page Down` and `Page Up`, so it works with the deck.

![Three steps forward, one step back, a black screen, and the last slide](https://raw.githubusercontent.com/rellen/expresso/media/present-keys.gif)

### The mouse and the touch screen

A click or a tap on the right two thirds of the window goes to the next step. A click or a
tap on the left third goes to the previous step. On a touch screen, swipe left for the next
step, and swipe right for the previous step. A click on a link of the `goto` option goes to
its slide and step. A click on another link goes to the link.

### The overview

The overview shows each slide at its last step, in a grid that fits the window. In the
speaker view, only the speaker window shows the overview. The overview knows these keys:

<!-- keys overview -->

| Key | Action |
| --- | --- |
| `?` | This list of keys. The next key closes it. |
| `j`, `→`, `Page Down`, `Space` | Select the next slide |
| `k`, `←`, `Page Up` | Select the previous slide |
| `↓` | Select the slide below |
| `↑` | Select the slide above |
| `Home` | Select the first slide |
| `End` | Select the last slide |
| `Enter` | Step 1 of the selected slide |
| Click or tap a slide | Step 1 of that slide |
| `o`, `Esc` | Close the overview. The step does not change. |

<!-- /keys -->

![The overview opens, the selection moves two slides, and Enter goes to that slide](https://raw.githubusercontent.com/rellen/expresso/media/present-overview.gif)

### The transitions

A move to a different slide in the present view fades the old slide out and the new slide
in. The `transition` option of the deck or of a slide sets a different kind. A move back
plays the same kind in reverse. A move to a different step inside a slide uses the
animations of the overlays.

![The second slide pushes the first slide out to the left, and a move back brings it in](https://raw.githubusercontent.com/rellen/expresso/media/transition-slide.gif)

The transitions need the View Transitions API of the browser. A browser without it, and a
user who asks for reduced motion, get an instant change. The speaker view has no
transitions.

### The address

The address of the document holds the slide and the step. For example, `deck.html#4.2` is
step 2 of slide 4. A reload shows the same step, and a link can go to one slide.

### The speaker view

The speaker view shows the current step, the next step, the notes of the slide, the
position and a timer. Put this window on your screen, and put the first window on the
projector. The keys operate in either window, and the two windows show the same step. `b`
in the speaker view gives a black screen to the audience. The speaker view knows these
keys:

<!-- keys speaker -->

| Key | Action |
| --- | --- |
| `j`, `→`, `↓`, `Page Down`, `Space` | Next step, or the first step of the next slide |
| `k`, `←`, `↑`, `Page Up` | Previous step, or the last step of the previous slide |
| `Home` | First slide |
| `End` | Step 1 of the last slide |
| 0 to 9 | Type a slide number |
| `Enter` | Step 1 of the slide that you typed |
| `b` | Black screen. The next key shows the slide again. |
| `r` | Set the timer to 0:00 |
| `f` | Full screen on or off |
| Click or tap the right two thirds, or swipe left | Next step |
| Click or tap the left third, or swipe right | Previous step |
| `o` | Overview of the slides. Only this window shows it. |
| `?` | This list of keys. The next key closes it. |

<!-- /keys -->

![The speaker view: the current step, the next step, the notes, the position, the timer and the time left](https://raw.githubusercontent.com/rellen/expresso/media/present-speaker.png)

The timer starts at the first change of the step. If the browser blocks the second window,
let the document open windows.

### The time of the talk

Write `duration 20` in the deck to give the talk a length of 20 minutes. The speaker view
then shows the time left under the timer. The time left turns amber when you are more than
one minute behind, and red after the end of the time.

Each step gets the same part of the time. You are behind when you used more time than the
steps before the current step get.

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

The handout view shows one page for each step of each slide. A printer gets this view with
no key. In this view, only these keys operate, so the other keys scroll the pages:

<!-- keys handout -->

| Key | Action |
| --- | --- |
| `j` | Next step. The present view then shows it. |
| `k` | Previous step. The present view then shows it. |
| `p` | Present view |
| `a` | Every step, or the steps of the handout option. A print shows the same. |
| `?` | This list of keys. The next key closes it. |

<!-- /keys -->

![The handout view: three pages, one for each step, with the notes under each page](https://raw.githubusercontent.com/rellen/expresso/media/present-handout.png)

A slide can select the steps that get a page, with the forms of `at`:

```elixir
slide "overlays" do
  handout [3, :last]
  # ...
end
```

`handout :last` gives the last step only, and `handout :all` gives each step. `:last` can
also go in a list, such as `[2, :last]`. Write `handout :last` in the deck to give only the
last step of each slide that has no `handout` option. The handout view on a screen shows the
same pages as the paper. The speaker view still shows each step.

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

### The layout check

`?check` at the end of the address, such as `deck.html?check`, finds an element that goes
past an edge of the window and a line of code that breaks. A report in a corner of the
window gives each problem, with a link to its step. See
[Check that a deck fits the screen](docs/how-to/check-the-layout.md) and
[the layout check](docs/reference/layout-check.md).

### The custom properties of a theme

A theme can set these custom properties:

| Property | Effect |
| --- | --- |
| `--transition-dur` | The length of a transition. |
| `--pace-behind-color`, `--pace-over-color` | The colors of the time left. |
| `--progress-color`, `--progress-height` | The color and the height of the progress bar. |
| `--slide-number-color`, `--slide-number-size` | The color and the size of the slide number. |
| `--slide-number-right`, `--slide-number-bottom` | The position of the slide number. |
| `--goto-color` | The color of a link of the `goto` option. |
| `--digits-color`, `--digits-background` | The colors of the slide number that the presenter types. |

## Make a binary

Burrito makes a binary for macOS and for Linux, on x86_64 and on aarch64:

```sh
mix release expresso_cli_app
```

The command needs Zig 0.16.0 and `xz` on the path. The Nix shell gives both, and so does
the hook of a remote Claude Code session.

The binary takes the same arguments as the mix task, `--watch` too, and it gives the same
exit status. Its usage text has the file name of the binary, such as
`Usage: expresso_cli_app_linux_x86 <input> [output]`.

The first run of a binary installs its release on the computer, in a directory that has
the version of the release. A later binary of the same version runs that installed release,
and not its own. Therefore change the version in `mix.exs` for each binary that you give
to other users. `<binary> maintenance uninstall` removes the installed release.

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
`docs/development.md` gives more detail, and it tells you how to get a toolchain without
Nix.

## Documents

`mix docs` makes the documentation with ExDoc, and https://rellen.github.io/expresso/
shows the result of the last push to `main`. ExDoc groups the documents by their type.

How-to guides give the steps of one task, with the code of a deck and a recording of it:

- [Add transitions between slides](docs/how-to/add-transitions.md)
- [Animate elements in a slide](docs/how-to/animate-elements.md)
- [Make a deck from data](docs/how-to/make-a-deck-from-data.md)
- [Show code on a slide](docs/how-to/show-code.md)
- [Check that a deck fits the screen](docs/how-to/check-the-layout.md)

Reference pages describe each value of an option:

- [The transition option](docs/reference/transition-option.md)
- [The overlay options](docs/reference/overlay-options.md)
- [The css option](docs/reference/css-option.md)
- [The goto option](docs/reference/goto-option.md)
- [The code element](docs/reference/code-element.md)
- [The layout check](docs/reference/layout-check.md)
- [The template option](docs/reference/template-option.md)
- [The theme option](docs/reference/theme-option.md)

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
