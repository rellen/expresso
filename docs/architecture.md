# Architecture

This document tells you how Expresso makes an HTML document from a deck. It gives the
structure of the code at this time. It also names the parts that are not complete.

## The two input paths

Expresso has two ways to make an `Expresso.Deck` struct. Both paths reach HTML.

### The imperative path

A script makes a deck with the functions of `Expresso.Builder`, and the script returns the
deck.

```elixir
import Expresso.Builder

deck(
  [
    slide("heading_with_text_box",
      heading: "This is a heading",
      elements: [text_box(elements: [text_area(text: "This is a text-area inside a text-box.")])]
    )
  ],
  name: "demo"
)
```

`Expresso.main/2` reads a file of this kind. The section "The render pipeline" gives the
steps.

The functions come from the DSL. `Expresso.Builder.Generator` reads the definition of
each entity of `Expresso.Extension`, and it makes one function for each entity. A
function builds its struct with `Spark.Dsl.Entity.build/5`, which the macros of the DSL
also call. `Expresso.Builder.deck/2` makes the state that a module of the DSL has, and it
runs the transformers and the verifiers of the extension on it. Then
`Expresso.from_dsl_state/1` makes the deck, as `Expresso.parse/1` does for a module. Thus
the two paths give the same deck, and `test/expresso/builder_test.exs` makes sure that
they give the same HTML.

Spark has no public function for this work, so the generator depends on two parts of
Spark that are not public: `Spark.Dsl.Entity.build/5` and the form of the DSL state.
After an update of Spark, the parity tests find a change of either part.

### The DSL path

A module declares a deck with the Spark DSL. The script returns the module.

```elixir
defmodule Expresso.Example do
  use Expresso

  name "my presso"

  slide do
    text_box do
      text_area do
        text "hello, world!!!"
      end
    end
  end
end
```

`Expresso.parse/1` reads the DSL state of such a module. It returns an `Expresso.Deck`
struct, and it numbers the slides with `Expresso.Deck.number_slides/1`. The metadata map
of the deck holds the options of the deck:

| Option | Default |
| --- | --- |
| `progress` | `true` |
| `handout` | `:all` |
| `print_notes` | `true` |
| `slide_numbers` | `false` |
| `duration` | `nil` |
| `transition` | `:fade` |
| `effect` | `:fade` |
| `speed` | `nil` |
| `easing` | `nil` |
| `css` | `nil` |

The renderer puts the style sheet of `css` into the document after the theme.

The `slide` entity has a `heading` option. An author writes it as a call inside the block
of the slide, in the form of Spark:

```elixir
slide "intro" do
  heading "An intro"

  text_box do
    text_area do
      text "..."
    end
  end
end
```

Spark puts the option into the `heading` field of the struct. The templates read the
heading from the metadata. Therefore `Expresso.from_dsl_state/1` calls `Expresso.Slide.put_options_in_metadata/1` for each
slide, and that function puts the heading into the metadata. The default slide template
writes the heading container only when the metadata contains a heading.

## The render pipeline

`Expresso.main/2` does these steps:

1. `File.stat/1` makes sure that the input file is present.
2. `Code.eval_file/1` evaluates the input script.
3. `Expresso.to_deck/1` makes an `Expresso.Deck` struct from the value of the script.
4. `Expresso.Deck.render/1` makes the HTML.
5. The function writes the HTML to the output file, or to the standard output.

With `-` as the input path, the function reads the script from the standard input with
`IO.read/2`, and `Code.eval_string/3` evaluates it in place of steps 1 and 2. With `-` as
the output path, step 5 writes to the standard output.

When a step fails, the function writes the message to the standard error and returns an
error tuple. The standard output then holds no text. A failed write of the output file is
also an error.

The function also has a clause for `nil`, which writes the usage text of the mix task to
the standard error and returns an error tuple. The two commands never call the function
with `nil`: "The two commands" below tells what they do for a command with no argument.

`Expresso.to_deck/1` accepts three values:

| Value | Operation |
| --- | --- |
| An `Expresso.Deck` struct, such as the result of `Expresso.Builder.deck/2` | The function returns the struct. |
| A module that uses the DSL | The function calls `Expresso.parse/1`. |
| The tuple of a `defmodule` expression | The function reads the module from the tuple. |

A script that ends with a `defmodule` expression returns the third value. Therefore a script
that declares a deck module needs no other line.

`Expresso.to_deck/1` reads `spark_is/0` to know a module of the DSL. Spark writes this
function into each module that uses `Expresso`. For a different value the function returns
an error tuple, and `Expresso.main/2` writes the message.

`Expresso.Deck.render/1` does these steps:

1. `Expresso.load_templates/0` compiles each file in `./priv/templates/decks/` and in
   `./priv/templates/slides/`. The presenter bundle is not a part of this step. It comes
   from `mix compile`, before any of these steps.
2. `Expresso.Renderer.render/1` makes an HTML tree with Temple.
3. `Phoenix.HTML.safe_to_string/1` makes a string.
4. `Floki.parse_document!/1` and `Floki.raw_html/1` normalize the string.
5. The function puts `<!DOCTYPE html>` and a newline in front of the string.

The wildcard of step 1 is relative to the working directory of the command. This
repository has no `priv/templates/` directory, so step 1 compiles no file here. A deck
that needs a custom template gives a module instead. See "The templates".

Step 5 is necessary because Floki drops a doctype node. Therefore the renderer cannot
write the doctype, and the deck function adds it after step 4. Without the doctype a
browser uses the quirks mode, and the layout is not correct.

### The two commands

Two entry points run a command line:

- `Mix.Tasks.Expresso`, for `mix expresso`.
- `Expresso.BurritoEntryPoint`, for the binary that Burrito makes.

Each entry point calls `Expresso.CommandLine.run/3` with the name of the command and its
help text, so the two commands take the same arguments. `run/3` reads the arguments with
`Expresso.CommandLine.parse/1`, runs them, and returns the exit status:

| Arguments | Operation | Exit status |
| --- | --- | --- |
| `--help` or `-h`, in any position | Writes the help text. | 0 |
| `--version`, in any position | Writes the version from `mix.exs`. | 0 |
| An unknown option, or a third path | Writes `Unknown option:` or `Unexpected argument:`, and the usage text, to the standard error. | 1 |
| No input path | Writes the usage text to the standard error. | 1 |
| `<input> [output]` | Calls `Expresso.main/2`. | 0, or 1 for an error |
| `<input> [output] --watch` | Calls `Expresso.Watch.run/3`. See "The watch mode". | 1, after an error |

Each argument that starts with `-` is an option, except `-` alone. `-` is a path, and
`Expresso.main/2` reads it as the standard input or the standard output. A path that
starts with `-` needs a directory in front of it, such as `./-deck.exs`.

The parser does not use `OptionParser` from Elixir. That module reads `--` as the end of
the options, `--no-watch` and `--watch=true` as forms of `--watch`, and `-1` as a path.
Each of these arguments starts with `-`, so the command gives each one as an unknown
option.

A mix task that returns gives the exit status 0, so `Mix.Tasks.Expresso` exits with
`exit({:shutdown, 1})` for the status 1. Its help text is its `@moduledoc`, which is also
the text of `mix help expresso`. The task does not call `Mix.Tasks.Help.run/1`. That
function runs `deps.loadpaths` again, and `deps.loadpaths` changes the working directory
of the VM for a moment. In `mix test`, the tests that run at the same time then do not
find their files.

The launcher of Burrito starts the VM with `-s elixir start_cli`. After the boot, the CLI of
Elixir runs the first argument as a script, and then it halts the VM. Therefore
`Expresso.BurritoEntryPoint.start/2` runs the command before it returns, and it halts the
VM with the exit status. The CLI of Elixir then does not start. The binary also catches an
exception from the deck, writes the message, and gives the exit status 1. For the mix
task, Mix writes the exception.

The standard output can close before the command writes all the HTML, as for `| head`:

- In `mix expresso`, the writer of the VM gets `epipe` and stops. `IO.puts/1` then raises
  `:terminated`, and `Expresso.main/2` returns `{:error, :closed}`. The task stops with no
  message and the exit status 0. A filter of the logger drops the report of OTP about the
  writer, because the logger cannot write that report to the standard output either.
- In the binary, the launcher of Burrito 1.6 passes the standard output of the VM through a
  pipe. When the reader stops, the launcher stops the read of that pipe, and it sends
  SIGTERM to the VM. The default handler of OTP then stops the VM in order, and that stop
  waits for ever, because each write to the standard output waits. `Expresso.SignalHandler`
  halts the VM at once for SIGTERM, with the exit status 0. The moduledoc of that module
  tells why the status is 0.

## The watch mode

`mix expresso deck.exs --watch` serves the document at `http://127.0.0.1:4100/`. After
each change to a file of the deck, it renders the deck again, and the page reloads on the
same step. `--port` gives a different port, and the binary takes the same options.

`Expresso.Watch.run/3` does these steps:

1. `Expresso.Watch.Server.start/1` starts the web server.
2. `Expresso.render_file/1` makes the HTML inside `Expresso.DeckFile.track/1`, which
   records each file that the render reads. `render_file/1` returns an error tuple for each
   failure and does not raise, so a deck with an error does not stop the watch mode.
3. After a good render, `Expresso.Watch.Server.publish/2` serves the new document, and the
   page reloads. With an output path, the watch mode also writes that file.
4. After a failed render, the watch mode writes the error to the standard error. The page
   keeps the last good document, and the output file does not change.
5. Two times each second, `Expresso.Watch.Files.snapshot/1` records the state of each file
   of the deck. When `Expresso.Watch.Files.changed?/2` finds a change, the watch mode goes
   back to step 2.

The watch mode watches these files:

- The deck file.
- Each image, diagram and style sheet that the last render read. `Expresso.Image`,
  `Expresso.Element.Diagram` and `Expresso.Css` read these files with
  `Expresso.DeckFile.read/1`, which records the path only inside
  `Expresso.DeckFile.track/1`. Thus the three modules need no code for the watch mode.
- The custom templates in `./priv/templates/`. See "The templates".

`Expresso.DeckFile.read/1` reads a relative path from the working directory of the
command. A deck file is a script, and `Code.eval_file/1` gives it no base directory of its
own. The `root` option of the deck gives one, such as `root __DIR__`, and
`Expresso.PathTransformer` joins each relative path of the deck to it at compile time.
`docs/reference/root-option.md` lists the paths.

The option is a choice of the deck, and a deck without it keeps its paths from the working
directory. A base from the deck file for each deck would change the paths of each deck
that renders from the directory of its project, such as the examples of this repository.

The transformer is the first place that knows the option. An entity of the DSL is made
before the options of the deck are known, so an entity cannot join a path to the root.
The image, the diagram, the embed and the style sheet read their files at render time, so
the joined path is enough for them. The code element reads its file at compile time, as
"The code" tells, so the transformer also reads that file.

The watch mode does not see a file that the deck script reads by itself, for example with
`File.read!/1` or `Code.require_file/1`. A failed render can stop before it reads each file
of the deck, so the watch mode also keeps the files of the earlier renders.

Each render evaluates the deck file again, so a deck module gets a new definition each
time. During the render only, the watch mode sets the compiler option
`ignore_module_conflict`, so the compiler does not warn about the new definition.

### The contract and the parts that can change

The user sees these parts of the watch mode, and a later version must keep them:

- The options `--watch` and `--port`.
- The address `http://127.0.0.1:<port>/`, and a page that reloads on the same step.
- The output file after each render that succeeds.
- The messages on the standard output and on the standard error.

Two parts are internal, and a later version can replace each one:

- `Expresso.Watch.Files` finds the changes. It reads the file system two times each
  second. A replacement can use the events of the operating system, for example with the
  package `file_system`. On Linux, that package needs `inotifywait` from `inotify-tools`.
  A replacement must then read the file system when `inotifywait` is not present, so the
  user never installs a program for the watch mode.
- `Expresso.Watch.Server` serves the page and makes it reload. The script in the page asks
  the server for the number of the last render two times each second. A replacement can
  push the reload over a WebSocket, for example with Bandit. The module owns the server
  and the script, so the two always change together. The path `/version` is not a part
  of the contract.

The first version reads the file system and uses `:httpd`, because the two need no
dependency. They also work in the same way on each operating system and in the binary.
A deck has a small number of files, so a snapshot two times each second costs little.
The cost is a delay of 500 milliseconds or less before each render and each reload.

### The server

The server is `:httpd` from the `inets` application of OTP. `mix.exs` puts `:inets` in
`extra_applications`, so the release of the binary holds it. The server listens on
127.0.0.1 only, so a different computer cannot read the deck.

But a web page that the user opens can try DNS rebinding. The page's host name first
points to the page's own server, and then to 127.0.0.1. The browser then sends the page's
requests to the watch server, but each request still has the page's host name in its
`Host` header.

`Expresso.Watch.Host` is the first module in the `:httpd` module list. It passes a request
only when the `Host` header is `127.0.0.1` or `localhost`, and it answers each other
request with the status 403. The port is not part of the check, because a tunnel can use a
different port.

The server serves a private directory in the temporary directory of the system, and that
directory holds two files:

- `index.html` is the last good document, with the reload script in front of the last
  `</body>`.
- `version` holds the number of that render.

`Expresso.Watch.Server.publish/2` writes the document first, and then the number. Each
write goes to a temporary file, and a rename then replaces the file, so the server never
sends a part of a file. The output file of the command does not get the script.

The address holds the slide and the step, so a reload shows the same step. The speaker
view opens the same address, so it gets the script and reloads too. `window.opener` stays
after a reload, and the present view finds the speaker view again from its next message.
See "The messages between the windows".

Ctrl-C halts the VM at once, so the private directory stays in the temporary directory of
the system. It holds one document, and the system removes it with its other temporary
files.

## The document

`Expresso.Deck.render/1` writes one HTML document with this structure. Each part below
the doctype comes from `Expresso.Renderer.render/1`:

```
<!DOCTYPE html>
html
  head
    title            the name of the deck
    style            assets/fonts.css, with the bytes of each font file in it
    style            assets/style.css
    style            the rules of the token classes of a code element, from Makeup
    style            the generated rules of the overlays, from Expresso.Overlay.Render
    body           data-view "present", and data-progress and data-print-notes
                   from the deck, and a style with --overview-columns and
                   --overview-zoom
      div            the present view, class "screen"
        section      one for each slide, class "slide", id "slide-<number>",
                     data-step "1", data-max-step from the slide
          div        the header, from the deck template
          div        the body, from the slide template
          div        the footer, from the deck template
            span     the slide number, class "slide-number", with slide_numbers: true
      div            the handout view, class "handout"
        section      one for each step of each slide, class "handout-page",
                     data-step from the step, data-slide from the slide,
                     data-index from the index of the step in the list of the
                     steps, data-omit when the handout option does not select
                     the step, data-thumbnail and data-commands on the page of
                     the last step of the slide
          div        the same three parts as a slide of the present view
          aside      the notes of the slide, class "notes", when the slide has notes
        div          the four elements of the speaker view: speaker-notes,
                     speaker-position, speaker-timer and speaker-left
      div            the progress bar, id "progress"
      div            the list of keys, id "help"
        div          one for each mode that has bindings, data-mode from the
                     mode, hidden
          div        one for each binding, with a kbd and a span
      script         the list of the steps as JSON, id "expresso-deck",
                     type "application/json", from Expresso.Steps
      script         the program of the presenter as JSON, id "expresso-program",
                     type "application/json", from Expresso.Presenter.Program
      script         priv/static/presenter.js, the presenter bundle
```

The two views hold the same slides. Therefore a selector on the full document finds each
element two times. A test that counts an element, or that reads its text, must select
inside `.screen` or inside `.handout`.

### The font

The document of a deck is one file, and a font cannot be a second file.
`assets/fonts.css` holds one `@font-face` rule for each face of the theme, and each rule
names a file under `assets/fonts/`. `Expresso.Font` reads that stylesheet at compile time,
and it replaces the path of each `url()` with a data URI of the file.

Therefore a browser needs no network for the font. A document with a `@import` of a font
service looks correct on the machine of the author. At a conference with no network, it
loses the font. It also gives the address of each person who reads the deck to that
service.

Atkinson Hyperlegible is the font, and the Braille Institute of America gives it under the
SIL Open Font License, Version 1.1. `assets/fonts/OFL.txt` holds that license, and the
license permits this use. The eight files take approximately 110 kilobytes, and the data
URIs take approximately 147 kilobytes of the document.

### The style sheets and the bundle

The renderer holds the two style sheets and the presenter bundle in module attributes.
It reads them with `File.read!/1` at compile time. Each style sheet, and each source of the
bundle under `assets/src/`, is an `@external_resource` of the module. Therefore a change to
one of these files starts a new compile of `Expresso.Renderer`. Elixir compares the content
of an external resource, and not its time, so a `touch` does not start a compile.

The `css` option of a deck can name a font or a picture with `url()`. The document is one
file, so `Expresso.Css.render/2` puts each local file of a `url()` into the style sheet as a
data URI at render time, as `Expresso.Font` does for the font of the theme. A relative
path resolves as in a browser: from the directory of a CSS file, or from the base of the
deck for a style sheet in the option itself. The base is the `root` option, or the working
directory. Thus a CSS file that works in a browser next to its files also works in a deck.

`Expresso.Theme` reads `assets/style.css` in the same way, with `Expresso.Css.scan/1`. It
gives the names of the custom properties, the effects and the transitions of the theme to
three verifiers: `Expresso.Overlay.PropertyVerifier`, `Expresso.Overlay.EffectVerifier`
and `Expresso.TransitionVerifier`. `docs/overlays.md` gives the rules of the first two, and
"The transitions" gives the rules of the third.

### The colors

`assets/style.css` declares no color. Each color is a custom property of a role, such as
`--text`, `--accent` or `--code-keyword`. The renderer writes the roles of the theme of
the deck on `:root`, at the start of the style element of the theme. It also writes the
roles of the default theme for `@media print`. The `css` option of the deck comes later,
so it can replace a role.

`Expresso.Palette` gives each role a color of a base16 scheme, and it holds the contrast
minimums of WCAG and APCA. `Expresso.Palette.Builtin` reads the schemes of `assets/themes/`
at compile time, and it adjusts the lightness of each color that fails. The compile stops
for a scheme that needs a change of more than 0.4. `Expresso.ThemeVerifier` gives a
warning for a scheme of a deck that fails, and `Expresso.Color` calculates the contrast
and the lightness. `docs/reference/theme-option.md` gives the roles, the minimums and the
built-in themes.

### The contrast of a theme

This section gives the formulas of `Expresso.Color` and `Expresso.Palette`, and it tells
why the minimums have their values. Each constant of a formula is a module attribute with
a name, such as `@wcag_flare` or `@apca_black_threshold`.

#### Two measures of contrast

`Color.contrast/2` returns the contrast ratio of WCAG 2.2, from 1 to 21:

1. Decode each channel of sRGB to a linear value, with the transfer function of
   IEC 61966-2-1.
2. Calculate the relative luminance: `L = 0.2126 R + 0.7152 G + 0.0722 B`.
3. Calculate the ratio: `(L_lighter + 0.05) / (L_darker + 0.05)`.

The value 0.05 stands for the flare of a screen. On a dark background, both luminances
are small, and the ratio of two small numbers grows fast. Thus the ratio gives a dark pair
more contrast than a reader sees.

`Color.lightness_contrast/2` returns the lightness contrast `Lc` of APCA-W3 0.0.98G-4g,
the method of the draft of WCAG 3:

1. Calculate a luminance with a simple power: `Y = 0.2126729 R^2.4 + 0.7151522 G^2.4 +
   0.0721750 B^2.4`.
2. Clamp a luminance near black: when `Y < 0.022`, `Y` becomes `Y + (0.022 - Y)^1.414`.
3. For dark text on a light background, calculate `S = (Y_background^0.56 -
   Y_text^0.57) × 1.14`. For light text on a dark background, calculate
   `S = (Y_background^0.65 - Y_text^0.62) × 1.14`.
4. When `|S|` is less than 0.1, `Lc` is 0. Otherwise, `Lc = (|S| - 0.027) × 100`.

`Lc` goes from 0 to about 108. APCA gives a negative value for light text, and Expresso
uses the absolute value. The order of the colors is important, because the text and the
background get different powers.

This table shows why a theme needs both measures:

| Text | Background | WCAG 2.2 | APCA |
| --- | --- | --- | --- |
| `#6272a4`, the comments of the Dracula scheme | `#21222c` | 3.36:1 | Lc 27 |
| `#7788bb`, the same color adjusted to 4.5:1 | `#21222c` | 4.53:1 | Lc 37 |
| `#a3b5eb`, the same color adjusted to 4.5:1 and Lc 60 | `#21222c` | 7.80:1 | Lc 60 |
| `#767676`, a gray | `#ffffff` | 4.54:1 | Lc 72 |

The second and the fourth row have the same contrast ratio. On white, APCA gives Lc 72. On
the dark background, it gives Lc 37, which is less than its minimum for large text.

#### The adjustment of a color

`Color.adjust/4` changes the lightness of a color until the color meets a contrast ratio
and an `Lc`:

1. Convert the color to OKLab. OKLab has a lightness `L` from 0 to 1 that agrees with the
   lightness that a reader sees, and two values `a` and `b` for the hue and the chroma.
2. Move `L` in steps of 0.001. The color becomes lighter on a background with an `L` under
   0.5, and darker on a lighter background. `a` and `b` stay the same.
3. When a color is outside sRGB, reduce `a` and `b` together, in steps of 1/50, until the
   color is inside sRGB.
4. Stop at the first color that meets both minimums.

The change of a color is the difference of `L`. The comment of Dracula in the table needs a
change of 0.22. `Expresso.Palette.Builtin` refuses a scheme with a change of more than
0.4, because a larger change gives a color that the reader does not know as a color of the
scheme.

#### A color that passes, for a theme from a map

A theme from a map is not adjusted, because its colors are the choice of the user.
`Expresso.ThemeVerifier` gives a warning for each role that fails, and
`Expresso.Palette.suggestions/1` puts a color that passes into each warning. The user can
then copy the color into the map.

The map gives a color to a slot, and a slot can color more than one role, such as
`base05` for `text` on `base00` and for `code_text` on `base01`. The function therefore
adjusts the color of the slot against each background of its roles in turn, and it keeps
the color only when the color meets the minimums on each of them. The two backgrounds of
a scheme usually have almost the same lightness, so the second adjustment moves the color
in the same direction as the first one. When no lightness passes, the warning says so, and the
user must change the background or the hue.

`adjust: true` applies `Expresso.Palette.adjust/1` to a map, as the build does for a
built-in theme. It is an option, and not the default, because the colors of a map are a
choice of the user, and a deck without the option keeps the colors that it gives. A
built-in theme with a change of more than 0.4 is refused at compile time, because the
repository chooses its built-in themes. A map with such a change still renders, because the
user asked for the adjustment, and `Expresso.ThemeVerifier` gives a warning.

#### Two variants of a theme

A light room and a dark room ask for different colors, and the presenter often does
not know the room before the talk. `theme dark: ..., light: ...` therefore puts both
variants into the document. `Expresso.Palette.variants/1` returns their palettes, and the
renderer writes the roles of each:

1. `:root` gets the light roles.
2. `@media (prefers-color-scheme: dark)` gives `:root` the dark roles.
3. `:root[data-scheme="light"]` and `:root[data-scheme="dark"]` give the roles of each
   variant. The attribute selector has more weight than `:root` alone, so it wins over
   the scheme of the screen.
4. `@media print` names `:root` and `:root[data-scheme]`, and it comes last, so paper gets
   the default theme with each variant.

The key `t` calls the built-in function `switch_scheme`, which writes `data-scheme` on the
`html` element. `data-variants` on the `html` element tells the function that the
document has two variants. Without it, the key changes nothing.

The presenter does not hold the variant in its state, because the variant at the start
comes from the screen, and the interpreter cannot read the screen. The two windows must
still show the same variant, because the speaker view shows the slides that the audience
sees. `main.ts` therefore keeps the choice outside the state:

- Each message between the windows holds `scheme`: `"light"`, `"dark"`, or `null` for the
  variant of the screen. The function reads it from `data-scheme`.
- `switch_scheme` sends a message after the change, with a new time. The other window
  takes a newer message as it takes a position, and it writes `data-scheme` from it.
- A window that opens gets the variant from `?scheme=` in its address. The key `s` writes
  that parameter for the speaker view. Without it, the first message of the speaker view
  would hold `null`, and it would change the variant of the present view back.

The default presenter binds `t` in the present view and in the speaker view.
`scheme.ts` holds the rules, and `dom.ts` reads and writes the attribute.

#### The dimmed colors

An opacity `o` changes each channel of a color to `o × color + (1 - o) × background`, and
the contrast of the color becomes less:

| Text and background | 1 | 0.8 | 0.65 | 0.5 |
| --- | --- | --- | --- | --- |
| The text of Dracula, `#f8f8f2` on `#282a36` | 13.36:1, Lc 99 | 9.10:1, Lc 73 | 6.55:1, Lc 55 | 4.52:1, Lc 39 |
| The comments of Dracula, `#a3b5eb` on `#21222c` | 7.80:1, Lc 60 | 5.54:1, Lc 45 | 4.16:1, Lc 34 | 3.04:1, Lc 23 |
| The numbers of the default theme, `#bb5407` on `#f8f8f8` | 4.51:1, Lc 68 | 3.28:1, Lc 58 | 2.59:1, Lc 49 | 2.03:1, Lc 38 |
| The text of the default theme, `#000000` on `#ffffff` | 21:1, Lc 106 | 12.63:1, Lc 99 | 7:1, Lc 84 | 3.95:1, Lc 67 |

The minimum of a dimmed element is 3:1 and Lc 30. 3:1 is the minimum of criterion 1.4.11
for a part that the reader must see. Lc 30 is the APCA minimum for any text that the
reader must be able to read. The presenter does not talk about a dimmed element now, but
the reader can go back to it.

Each role starts at a different contrast. `Color.adjust/4` stops at the minimum of a text,
so most roles start near 4.5:1 and Lc 60. The text starts far above them. Thus one opacity
for all the colors of an element must stop where the weakest role meets its minimum.

`Expresso.Palette` gives each role of text its own dimmed color. The dimmed color is the
role blended on its background at the smallest multiple of 0.05 that keeps 3:1 and Lc 30.

| Role | Dimmed color | Opacity | Contrast | One opacity for all |
| --- | --- | --- | --- | --- |
| The text of Dracula | `#86878b` | 0.45 | 3.97:1, Lc 34 | 0.65 |
| The comments of Dracula | `#7682a8` | 0.65 | 4.16:1, Lc 34 | 0.65 |
| The text of the default theme | `#8c8c8c` | 0.45 | 3.36:1, Lc 61 | 0.8 |
| The numbers of the default theme | `#ca7d43` | 0.75 | 3.03:1, Lc 55 | 0.8 |

On a dark theme, APCA sets the opacity of most roles. On a light theme, WCAG sets it, so a
light theme dims less.

The renderer writes each dimmed color as a custom property, such as `--text-dim`. The state
`dim` sets `--dim: 1` and `--dimmed: 1` on the element. `--dimmed` is registered to
inherit, so each element inside the dimmed element also gets `--dimmed: 1`. The style sheet mixes each color
of text toward its dimmed color with `color-mix(in srgb, ...)` and the value of
`--dimmed`. `Color.blend/3` and `color-mix()` both blend in sRGB, so the browser shows the
color that the palette measured. `docs/dim-state.md` gives the design and its decisions.

An image, an SVG file and an embed have colors that the palette does not know.
They dim with one opacity, `--dim-opacity`: the strongest opacity that keeps each role of
text at 3:1 and at Lc 30.

### The style of a slide

The renderer writes an inline `style` attribute on each `section` of the present view.
The first slide gets `display: flex`, and each other slide gets `display: none`. A
`section` of the handout view has no inline style, because the presenter does not touch
it. `assets/style.css` gives the style of each view.

Before the tree, the renderer calls `Expresso.Overlay.Render.identify/1` on the deck. It
gives each element with an `on` entity its `data-el` value. `docs/overlays.md` gives the
CSS contract of the overlays: the attributes, the base rules in `assets/style.css` and
the generated style block.

The class `.screen` gives the container `height: 100vh`, and each `section` gets
`height: 100%`. The viewport unit is necessary because the `body` gets `min-height`, and
a percentage height cannot resolve against a minimum height. With `height: 100%` on the
container, each slide takes the height of its content only.

A slide of the present view takes the full width of the window, and its `.slide-body`
takes the full width of the slide. A page of the handout view does the same in the width of
the page. A `columns` element thus divides the width of the window, and not the width of
its content. The custom property `--slide-padding` gives the space between the edge and the
content, `0 1rem` by default. The default slide template writes the heading with no inline
style, so a rule `h1` of the `css` option can align it.

## The templates

A template makes the HTML for a part of the document. There are two kinds.

A deck template gives a header and a footer. It implements the `Expresso.Template.Deck`
behaviour, which has the callbacks `header/1` and `footer/1`. The footer of the default
deck template is empty. The `slide_numbers` option gives the numbers of the slides.

A slide template gives the body of a slide. It has a `render/1` function.

`Expresso.Template` selects a template from the metadata. A slide template comes from
`slide.metadata[:template]`, then from `deck.metadata[:slide_template]`, and a deck
template comes from `deck.metadata[:template]`. The default value of each is
`{:builtins, :default}`. The `meta` option of a slide goes into `slide.metadata[:meta]`,
and not into the metadata itself, so a value of the user cannot replace a key that
Expresso reads. The private function
`module_from_template_definition/2` maps this value to a module name.

The value takes one of two forms. The tuple `{:builtins, name}` selects a built-in template.
A module selects that module. Therefore a template that `Expresso.load_templates/0` compiles
from `./priv/templates/` is available as a module.

The `template` option of the deck and of a slide gives each kind:

```elixir
defmodule MyDeck do
  use Expresso

  name "my deck"
  template MyDeckTemplate

  slide "first" do
    template MySlideTemplate
  end
end
```

`Expresso.Builder` takes the same option, such as `slide("first", template: MySlideTemplate)`.

## The elements

An element is the content of a slide. These are the elements at this time:

- `Expresso.Element.TextBox`
- `Expresso.Element.TextArea`
- `Expresso.Element.Image`
- `Expresso.Element.List`, with `Expresso.Element.Item`
- `Expresso.Element.Table`, with `Expresso.Element.Row`
- `Expresso.Element.Quotation`
- `Expresso.Element.Spacer`
- `Expresso.Element.Code`, with `Expresso.Element.Lines`
- `Expresso.Element.Columns`, with `Expresso.Element.Column`
- `Expresso.Element.Math`
- `Expresso.Element.Diagram`, with `Expresso.Element.Part`
- `Expresso.Element.Embed`
- `Expresso.Element.Video`
- `Expresso.Element.Audio`
- `Expresso.Element.QrCode`
- `Expresso.Element.Footnote`
- `Expresso.Element.Shape`

### The parts of an element module

An element module has these parts:

- A struct with a `__spark_metadata__` field, with the `at`, `on`, `steps` and `el`
  fields of the overlays, and with the `class` field of the `class` option.
- A `get_assigns/1` function. It makes a map of assigns from the struct. The key `overlay`
  holds the attributes from `Expresso.Overlay.Render.attributes/1`.
- A `render/1` function. It makes the HTML from the assigns, and it puts the `overlay`
  list on the root tag with `rest!: @overlay`. An element that writes text from the deck
  puts that text in one block element inside the root tag.

`Expresso.Template.render_elements/1` matches `%module{}` for each element. It then calls
`module.get_assigns/1` and `module.render/1`. There is no `@behaviour` for an element, and
the compiler does not make sure that a module has the two functions.

`render_elements/1` also puts the `class` field into the assigns, so `get_assigns/1` does
not need it. The render function writes `Expresso.Element.classes/2` of its own class and
`assigns[:class]` on the root tag. The class of the theme comes first, so each rule of the
theme still selects the element. The option is not part of the overlay attributes,
because the root tag already has a `class` attribute, and HTML takes only the first of
two. A table renders its rows itself, so it puts the class of each row into its assigns.

### The text box and the text area

A `text_box` contains other elements. A `text_area` contains text. The renderer writes the
text with `Phoenix.HTML.raw/1`, so the text can contain HTML.

The theme makes `.text-area` a flex container. Each element inside a flex container is a
flex item, and a flex item also holds each run of text between two elements. Therefore
text with an inline element, such as `<b>`, breaks into more than one line. The render
function of a text area puts the text in one block element, which is one flex item. A
custom element that writes text from the deck must do the same.

### The image

An `image` shows an image file. The document of a deck is one file, so the image cannot be
a second file. `Expresso.Image` reads the file at render time, and it makes a data URI from
the bytes. The `src` option gives the path, and the path is relative to the working
directory of the command. The extension of the path gives the media type, and
`Expresso.Image` accepts `.avif`, `.gif`, `.jpeg`, `.jpg`, `.png`, `.svg` and `.webp`. A
file that the function cannot read stops the render with a message that names the path.

The `alt` option gives the text of the image for a screen reader. An image with no `alt`
option is decorative, and the render function writes an empty `alt` attribute.

The `width` option gives the width of the image. The render function writes the value into
the custom property `--image-width` on the root tag, and the theme reads that property with
`var(--image-width, auto)`. A custom property inherits, so an `on` entity can also set the
property, and the width then changes with the step. This works only for an image with no
`width` option: the option writes a `style` attribute, and that attribute takes priority
over the rule of the `on` entity.

An image with no `width` option takes its natural size, and the theme makes it smaller for
a slide that is too small. Use a length, such as `900px`, or a percentage, such as `60%`,
for a larger image. A percentage is a part of the width of the slide.

The render function writes a percentage as a viewport unit, so `60%` becomes `60vw`. CSS
resolves a percentage against the container of the image, and that container takes the
natural width of the image. Therefore a percentage in CSS makes an image smaller only, and
`100%` changes nothing. A slide takes the full width of the screen and of the page, so a
viewport unit gives the meaning that an author expects.

The function changes a value that is one number and a percent sign only. The number takes
each form that CSS permits, so `60%`, `33.5%`, `.5%`, `+60%` and `6e1%` each become a
viewport unit. A value such as `calc(50% + 10px)` holds a percentage inside a function, and
it goes into the document as it is. `Expresso.Test.CSS` makes a random width for the
property tests of this rule.

The theme does not register `--image-width` with the `@property` at-rule. A registered
property always has a value, so the fall back to `auto` would not work, and each image
would take the width zero.

### The list

A `list` holds `item` elements, and an item holds text and one optional nested `list`.
`Expresso.Extension` builds three levels of the entities with a loop. The DSL accepts a
fourth level too, and `Expresso.ElementPagesTest` makes sure of it. The
`ordered` option gives an `ol` element, and the default is a `ul` element. The `reveal`
option shows the items one after the other, and `docs/overlays.md` gives its rules. The
text of an item goes into one block element, as in a text area, and it can contain HTML.

### The table

A `table` holds `row` elements, and a row takes a list of strings as its cells. Each cell
can contain HTML. The `header` option makes the first row the header, and the renderer
then puts it into a `thead` element with `th` cells. The `reveal` option shows the rows
one after the other, and the header row shows with the table. `docs/overlays.md` gives
the rules.

### The quotation

A `quotation` takes its text as its first argument, and the `by` option gives the name of
the source. The renderer writes a `figure` element with a `blockquote` element, and the
source goes into a `figcaption` element. The entity is not named `quote`, because
`Kernel.SpecialForms.quote/2` has that name, and a call of the DSL would be ambiguous.

### The spacer

A `spacer` has no content. The theme gives it `flex-grow: 1`, so it takes the free space
of its container and pushes the elements after it to the end. Two spacers around an
element put the element in the middle. Write `spacer()` with parentheses, as for `pause`.

### The code

A `code` element shows source code. The entity takes the name of the language as its
optional first argument. The `text` option holds the source, or the `src` option names a
file that holds it. `Expresso.Highlight` makes one HTML fragment for each line at render
time.

`Expresso.Element.Code.build/1` reads the file of `src`, and not the render function. The
check of the `reveal` option needs the lines, and the steps of the groups come from the
transformer, so the file must be read before the overlay transformer runs. The transform
of the entity calls `Expresso.Element.Code.check/1`, which checks the options and builds an
element with `text`. `Expresso.PathTransformer` runs before the overlay transformer, and it
calls `build/1` for each element with `src`, after it joins the path to the `root` option.
`Expresso.Builder.deck/2` runs the same transformers, so the compiler of the DSL and the
builder read the file in the same place. The function reads the file through
`Expresso.DeckFile`. Each render of the watch mode evaluates the deck
file again inside `Expresso.DeckFile.track/1`, so the watch mode also watches the file of
the code.

With `src`, a line keeps its number in the file, and `reveal` uses that number. The
author then reads the number of a group in the editor, and the slide shows the same number
with `line_numbers`. A count from 1 in the excerpt would need a calculation for each group.

A `lines` option with texts finds its range in the bytes of the file: from the line of the
`from` text to the line of the last character of the first `to` text after it. A change
above the excerpt then does not move it. The `from` text must be in the file one time, so
a new copy of it above the excerpt gives an error, and not a different excerpt.

Makeup lexes the text when a lexer registers the language. `mix.exs` lists one package for
each of these languages:

- Elixir, Erlang and Gleam
- EEx and HEEx
- HTML and CSS
- JavaScript and TypeScript
- JSON
- SQL
- C and Rust
- diff

Hex has no Makeup lexer for many other languages. The modules of `Expresso.Lexers` are
lexers of this project, and "The languages" in `docs/reference/code-element.md` lists them.
Each one is pure Elixir with NimbleParsec, so the binary of Burrito needs no native
library. A package with a native library, such as `makeup_syntect`, was the other choice.
It also registers approximately 200 names, and some of those names would replace the
lexers of Hex.

A slide needs clear colors, not a parser of each rule of a language. Therefore each lexer is
a short list of rules, and `Expresso.Lexer` gives the parts:

- `deflexer/3` defines the callbacks of `Makeup.Lexer`. It adds a last rule that takes any
  one character, so a lexer reads each text to its end. A property test makes sure that the
  tokens of each lexer give the text back.
- A rule makes one token, such as a comment, a string, a number, a word or a key before
  `=` or `:`. A table then gives a word its type, such as `:keyword` for `let`.
- `Expresso.Lexers.Lisp` holds the rules that Emacs Lisp and Fennel share: comments,
  strings, keywords such as `:key`, symbols, and the name after a definer such as `defun`.
  Each Lisp gives its own characters, definers and tables of words.
- `inline/3` matches a span of markup that opens and closes on one line, such as `*bold*`.
  Without its closing mark, the rule does not match, so a lone `*` stays text. The lexers of
  Org, reStructuredText, LaTeX and Typst color the structure of a document, and each other
  word stays text: a word of a sentence is not a keyword.
- `line_start/1` matches only at the start of a line, such as the table header of TOML. The
  rule starts with the line break before the line, and `lex/2` puts a line break before the
  text. With `indent: false`, it matches only at the first column, such as the name of a
  definition at the top level of Haskell. A condition in `pre_traverse/3` does not work
  here, because its error stops the whole parse, and the next rule does not get a chance.

The types of the tokens are the types of Makeup, so the rules of the theme give them their
colors. A string of several lines is `:string_heredoc`, because the theme gives
`:string_doc` the color of a comment. No application registers these lexers, so
`Expresso.Highlight` registers them when it starts the lexer packages.

Without a lexer for the language, the fragment is one `span` with the escaped text. A
line of a lexer is a sequence of `span` elements, so each line starts and ends with an
element. Floki removes the white space of the template between two elements, so that white
space does not join the text of a line.

`Expresso.CodeVerifier` gives a compile warning for a language that no lexer registers,
with the list of `Expresso.Highlight.languages/0`. A misspelled name, such as `"elixr"`,
otherwise gives code with no colors and no message. It is a warning and not an error,
because the code still shows its text.

`Expresso.Highlight` writes a rule for each token class, and the renderer writes them into the document in
their own `style` element. Each rule reads a role of the theme, such as `--code-keyword`,
so the code gets the colors of the theme.

A lexer gives each pair of delimiters, such as `(` and `)`, a `data-group-id`. Without the
option `group_prefix`, the id starts with a random prefix, and two renders of one deck are
not equal. `Expresso.Highlight` gives the prefix `:erlang.phash2/1` of the text and the
language. This hash is the same on each computer and each ERTS version. Therefore a deck
gives the same HTML on each render, also from the binary that Burrito makes.

The `reveal` option of a code element takes a list of line numbers and of ranges, such
as `[1..3, 4..8, 10]`. `Expresso.Element.Code.build/1` makes one `Expresso.Element.Lines`
child for each item, with the specification `[from: :next]`. The transformer then gives
each group its steps, as it does for the items of a list. Each line goes into a `span`
element, and a hidden line keeps its space. `docs/overlays.md` gives the rules.

A line number that the element does not show gives an error. Such a group shows nothing,
and it takes one step of the slide.

The `highlight` option uses the same groups, with no `at` option. `build/1` gives each
group an `on` entity with `:next` and the state `highlight`, and it puts the lines in no
group into one more group. The transformer then gives each group its step. The other lines
must dim at that step, and the step is known only after the transformer. Therefore
`Expresso.Element.Code.spotlight/1` runs in `Expresso.Renderer.render/1`, before
`Expresso.Overlay.Render.identify/1`. It gives each group an `on` entity with the state
`dim` at the steps of the other groups. The style block then holds plain rules of the
contract, and the presenter and the handout view need no new code.

`Expresso.Deck.render/1` writes the document with Floki, and Floki drops a text node that
is only white space. A line of code holds such nodes: an indentation, a space between two
tokens, a line break. Therefore `Expresso.Highlight` puts each white space token into the
span of the token before it. A line that has no other character gets a zero width space.
An element that writes text with significant white space must do the same.

A code element that is alone in its parent grows, and its code stays in the center, as a
text box does. Two code elements in one parent, such as two excerpts in a column, would
each take half of the free height, and each would center its own lines. Their lines then
start at two different places, and a large gap separates them. Therefore code elements
that share a parent do not grow, and their code starts at the left edge of the parent. The
rule `.code:has(~ .code), .code ~ .code` of `assets/style.css` finds them.

### The columns

A `columns` element puts its `column` elements side by side, and a column holds the same
elements as a text box. The theme makes the element a flex row. A column without a
`width` option takes an equal part of the free space. A column with the option, such as
`width "30%"`, takes that width. The render function writes the custom properties
`--column-width` and `--column-grow` on the column, and the theme reads them.

A column takes the `at` option and the `on` entity. The extension does not give `columns`
or `text_box` as a child of a column, but the DSL accepts both in a column, and they
render in the column. `Expresso.ElementPagesTest` makes sure of it.

### The math

A `math` element takes MathML as its first argument, from the `<math>` tag to the
`</math>` tag. A browser renders MathML Core without a script and without a font file,
and each browser of the floor of this project supports it. The text goes into the
document as it is. Give the `math` tag the attribute `display="block"` for a formula on
its own line.

### The diagram

A `diagram` shows an SVG file. The `src` option gives the path, as for an image. The
render function puts the SVG into the document as an element, and not as a data URI.
Therefore the rules of the theme reach the parts of the diagram.

A `part` entity names an element of the file by its `id`, and its `at` option and `on`
entities give the steps. The parts are the children of the diagram, so the transformer
and the verifier treat them as elements. The render function writes the overlay
attributes of each part on the element of the file that has its `id`. A file without
that `id` stops the render with a message that names the id and the path.

A part with an `on` entity, or with an effect that moves or grows it, goes into a wrapper.
The wrapper is a `g` element with the class `diagram-part`, and it gets the attributes.
The theme moves and outlines the wrapper, so the part keeps its own `transform` attribute.

The `width` option gives the width of the diagram, as the option of an image does. The
render function writes it into the custom property `--diagram-width`. A diagram without
the option takes the width that the file gives.

The document holds one copy of the file for the present view and one for each page of the
handout view. A browser resolves a reference such as `url(#fill)` to the first element of
the document with that `id`. A gradient in a hidden view then does not paint. Therefore
the render function gives each copy its own ids. It puts a number after each `id`, and it
puts the same number into each `url(#id)` and each `href="#id"` of the copy. The number
comes from `System.unique_integer/1`, so two renders of one deck give different numbers.

The document passes Floki, and Floki writes each name of an SVG in lowercase, such as
`viewbox`. A browser reads the lowercase names inside an `svg` element as the names of
SVG, so the diagram keeps its meaning.

The `move_to` option of an `on` entity in a part names a different element of the file.
`Expresso.Element.Diagram.place/1` runs before the render, and it replaces each `move_to`
with `x` and `y` in `set`. `Expresso.Element.Diagram.Geometry` gives the distance from the
center of the part to the center of the target. These are the reasons for this design:

- **Elixir measures, and not the browser.** A browser measures each shape exactly, but the
  script would then need to measure each copy of the diagram, a hidden copy has no layout,
  and paper gets no script. A distance in the style block works in each view and on
  paper, with no new code in the presenter.
- **The measure is of the attributes.** The module reads the shapes and the `transform`
  attributes, and not the style sheet. The theme moves a part with CSS, so a part keeps the
  same measure at each step. A text has no size without its font, so a text gives its
  start point.
- **The distance is in the coordinates of the parent of the part.** The wrapper of a part
  is in the same parent as the part, and the theme moves the wrapper. A parent with
  `scale(2)` therefore gets half the distance of the file.

### The embed

An `embed` shows a web page in a frame. `docs/reference/embed-element.md` gives the options
for the user. These are the reasons for its design:

- **No copy holds the source.** The document holds a copy of each slide for the present
  view and one for each page of the handout view. A source in each copy would load the page
  once for each step of the slide, and a local file would go into the document many times.
  Therefore `Expresso.Element.Embed.number/1` gives each embed a number, the frame holds
  only `data-embed`, and the renderer writes the sources one time into the element
  `expresso-embeds`. The form `written_embeds` of `Expresso.Presenter.Schema` describes it.
- **The presenter loads a page when its slide shows.** `embed.ts` gives the frame of the
  present view its source, after the load of the document. The slides then show at once, a
  page that loads slowly does not hold the load of the document, and the layout check does
  not wait for the network. The speaker view and the handout view load no page, so a page
  runs one time.
- **A loaded page stays.** A demonstration can have a state, such as the time of a
  simulation. A move back to the slide shows the page as it was.
- **A local file goes into `srcdoc`.** The deck then stays one file, as an image does.
- **The sandbox depends on the source.** A page of the network keeps its own origin with
  `allow-same-origin`. A local file has no origin of its own, and with `allow-same-origin` it
  would get the origin of the deck, so it gets `allow-scripts` only.
- **A frame takes no click by default.** A key goes to the frame that has the focus, and a
  deck cannot take it back from a page of a different origin. Without `interactive`, the
  frame has `pointer-events: none` and `tabindex="-1"`, so the focus stays on the deck.

### The video

A `video` plays a WebM or an MP4 file. `docs/reference/video-element.md` gives the options
for the user. It follows the design of the embed, with these differences:

- **The file goes into the document as a data URI, one time.** `Expresso.Media` gives
  each file a number, and two elements with the same file share it. Each copy of the
  slide holds only `data-video` and the poster, and the renderer writes the files into the
  element `expresso-videos`. The form `written_videos` of `Expresso.Presenter.Schema`
  describes it.
- **The step decides when it plays.** The player of `media.ts` runs after each change of
  the state. A
  video plays while its slide shows in the present view and each parent with an overlay
  shows at the step, so `at` gives the step where it starts.
- **A cover pauses it, and a new visit starts it again.** A black screen, the menu and the
  overview pause the video, and it goes on after them. A move to another slide and back
  starts it from the start, because the presenter shows it again from the beginning.
- **It has no sound.** A browser plays a video automatically only when it is muted. With
  `controls`, the video takes the clicks, and the presenter can turn the sound on.
- **It uses the box of an embed.** The element has the classes of an embed, so the size,
  the poster under the video, and the rules that hide the frame in the handout view and in
  the menu apply to it.

### The audio

An `audio` element plays a sound file. `docs/reference/audio-element.md` gives the options
for the user. It shares the design of the video: `Expresso.Media` numbers the files and
writes them into the element `expresso-audios`, and the player of `media.ts` plays them
with the rules of a video. `video.ts` and `audio.ts` each make one player from it. These
are the differences:

- **It has sound.** A browser refuses to play a sound before the first key or click of the
  user in the document. The player then leaves the sound paused, and the next change of
  the state tries again. A key of the presenter is such a change, so a sound of the first
  slide starts at the first key.
- **It shows nothing in the present view.** A sound has no picture, so the element shows
  only the controls of the browser with `controls true`. The handout view and paper cannot
  play it, and each of their pages shows the title with a note symbol, in a `figcaption`.
- **It does not loop by default.** A signal or a clip of speech plays one time. A video
  loops by default, because a video of a demonstration usually repeats.

### The QR code

A `qr_code` shows a QR code of a text. `Expresso.Element.QrCode` calls `EQRCode.encode/2`
at render time, and it writes the matrix of the code as SVG. These are the reasons for this
design:

- **One path, and not a square for each module.** The function joins the dark modules
  that touch in a row into one rectangle. A code for an address then has approximately
  300 rectangles in one `path`, and the document stays small.
- **SVG in the document, and not an image.** The code needs no file, and it prints at each
  size with sharp edges. `shape-rendering="crispEdges"` stops the browser from blurring the
  edges of the modules.
- **Its own colors.** A scanner reads a dark code on a light ground best, and a phone can
  fail on a light code on a dark ground. The theme therefore gives the code the custom
  properties `--qr-color` and `--qr-background`, black and white by default, and not the
  colors of the slide.
- **The quiet zone of the standard.** `EQRCode` draws a light border of two modules. The
  render function removes it and draws a border of four modules, as the standard asks.

The `size` option goes into the custom property `--qr-size`, with the rule of the width of
an image: `Expresso.Element.Image.viewport_unit/1` writes a percentage as `vw`.

### The footnote

A `footnote` gives a source at the bottom of a slide. It shows nothing in its place:
`Expresso.Template.render_elements/1` skips it, as it skips a `pause`. The renderer
collects the footnotes of a slide with `Expresso.Element.Footnote.of_slide/1`, and it
writes them as one `ol` after the slide template, in the slide parts. These are the reasons
for this design:

- **The renderer places the list, and not the template.** A custom slide template then
  gets the footnotes with no change. A list in the place of the element would put a
  source in the middle of the slide.
- **The browser gives the numbers.** The list is an `ol`, so the number of a footnote is
  its position. A footnote at a later step keeps its space and its number, because the
  overlay hides it with `visibility` and not with `display`.
- **`auto_reveal` skips a footnote.** A footnote supports a text, and a step of its own
  would show the source after the text, at a step with no other change.
- **One page of the sources.** The handout view gets a `section` with the class `sources`
  after the last page. It is not a `handout-page`, so the script does not count it as a
  step, and the style sheet hides it in the speaker view and in the overview.

### The shape

A `shape` draws a rectangle, an ellipse, a line or an arrow over a slide. It shows nothing
in its place, as a footnote does. The renderer collects the shapes of a slide with
`Expresso.Element.Shape.of_slide/1`, and it writes them into one `div` with the class
`shapes`, in the slide parts. These are the reasons for this design:

- **One layer over the slide.** The theme gives many elements a `transform`, and an element
  with a `transform` is the box of each child with `position: absolute`. A shape in its
  place would therefore take its percentages from its parent. In the layer, a percentage is
  always a part of the slide. The style sheet gives `position: relative` to a slide, to a
  page of the handout view and to a slide of the menu, so the layer covers each one.
- **A box is HTML, and a line is SVG.** A rectangle and an ellipse are a `div` with a
  border, so their text wraps as text. A line and an arrow are an `svg` over the whole
  layer, with a `line` from point to point. A percentage of a `line` is a part of the
  width or of the height of the `svg`, so it keeps its meaning in each direction, and the
  head of an arrow keeps its shape.
- **The head of an arrow has a new id in each copy.** A browser draws a `marker` from the
  first element with its id, and a marker in a hidden view does not paint. Each render of
  an arrow therefore gets an id from `System.unique_integer/1`, as each copy of a diagram
  gets new ids.
- **The color is `--color`.** A shape draws with `currentColor`, and its `--color` is
  `--shape-color`. The rules of the overlays mix `--color` with the dimmed color, so
  `set: [color: ...]` and the state `dim` change a shape with no new rule.
- **The layer takes no click.** `pointer-events: none` sends a click on a shape to the
  slide, so a click still shows the next step.

## The DSL

`Expresso.Extension` gives the Spark extension. It contains one section, `deck`, which is a
top level section. The section holds `slide` entities.

### The entities

- A `slide` holds `text_box` and `pause` entities. It also holds `image`, `list`, `table`,
  `quotation`, `spacer`, `code`, `math`, `diagram` and `columns` entities.
- A `text_box` holds `text_area` and `on` entities, and each element entity of a slide
  except `text_box` and `pause`.
- A `text_area` holds `on` entities.
- A `list` holds `item` entities.
- A `table` holds `row` entities.
- A `diagram` holds `part` entities.
- A `columns` element holds `column` entities, which hold the elements of a text box.

The `slide` entity takes an optional name as its first argument. The DSL accepts `slide do`
and `slide "name" do`.

### The options of the overlays

`docs/overlays.md` gives the meaning of each of these options:

- Each element has an `at` option.
- A slide has a `steps` option and an `auto_reveal` option.
- A list and a table have a `reveal` option.
- A code element has a `reveal` option with a list of lines.

A slide also has a `heading` option, a `notes` option and a `handout` option, and
`Expresso.Slide.put_options_in_metadata/1` puts each into the metadata of the slide.

### The notes

The `notes` option holds the notes of the speaker. The handout view shows them in an
`aside` element under each page of the slide, and the present view does not show them.
The text is not HTML, and a line break in the text gives a line break on the page.

The `print_notes` option of the deck leaves the notes out of the handout view and of the
print. The renderer writes `data-print-notes` on the `body` from the metadata of the
deck: `false` for `print_notes: false`, and `true` otherwise. The style sheet then hides
each `aside` in the handout view and on paper. The renderer still writes each `aside`,
because the speaker view reads the text of the notes from the page of the current step.

### The slide numbers

The `slide_numbers` option of the deck shows the number of each slide and the number of
slides, such as `3 / 12`. The renderer writes a `span` with the class `slide-number` into
the row of the footer, after the footer of the deck template. The number therefore shows
with each deck template. Slide 1 gets no number, because it is usually the title slide.
The default deck template gives an empty footer, so a deck does not show two numbers.

In the present view, the style sheet puts the number in the corner of the window.

### The transformer and the verifiers

The extension imports nothing, and it lists two transformers and eight verifiers:

- `Expresso.PathTransformer` joins each relative path of the deck to the `root` option, and
  it builds each code element with `src`. It runs first. See "The watch mode".
- `Expresso.Overlay.Transformer` expands the overlay specifications of each slide at
  compile time.
- `Expresso.GotoVerifier` refuses a `goto` option that names no slide. See "The links".
- `Expresso.Overlay.Verifier` reports a specification that breaks a rule.
- `Expresso.Overlay.PropertyVerifier` gives a warning for a custom property that neither
  the theme nor the CSS of the deck uses.
- `Expresso.Overlay.EffectVerifier` reads the `css` option of the deck. It gives an error
  for an effect without a rule in the theme or in that style sheet.
- `Expresso.TransitionVerifier` gives an error for a transition without a rule in the theme
  or in the CSS of the deck. See "The transitions".
- `Expresso.Overlay.SizeVerifier` gives a warning for a slide of very many steps.
- `Expresso.ThemeVerifier` gives a warning for each role of a theme from a map that does
  not meet its minimum, with a color that passes. See "The contrast of a theme".
- `Expresso.CodeVerifier` gives a warning for a language that no lexer registers. See
  "The code".

A verifier gives errors or warnings, and not both, so each kind of warning has its own
verifier.

After the transformer, each element and each `on` entity holds its step numbers in the
`steps` field. The metadata of the slide holds the maximum step number in `max_step`. It
holds the step labels in `labels`, a map from a step number to its name. The `labels`
option of the slide and the `label` option of each `pause` give them.
`docs/overlays.md` gives the rules.

## The presenter

The presenter has an Elixir part and a TypeScript part. The Elixir part tells what each
key, click and swipe does. The TypeScript part runs these rules in the browser.

The Elixir part is in `lib/expresso/presenter/`:

- `Expresso.Presenter.Default` holds the modes of the presenter and the bindings of each
  mode. A binding holds its events, its commands and its row in the list of keys. The
  module uses the Spark DSL of `Expresso.Presenter.Extension`.
- `Expresso.Presenter.Verifier` refuses a definition with an error when the module
  compiles. Examples are an unknown field, a value of the wrong type and a key with two
  bindings in one mode.
- `Expresso.Presenter.Projection` describes the projections, which tell how the script
  writes a state to the document.
- `Expresso.Presenter.Definition` holds the types of a definition, and it reads the
  definition of `Expresso.Presenter.Default` into maps.
- `Expresso.Presenter.Program` makes the program of one deck from the definition. It
  changes each symbol, such as the last slide, into a number for the deck.
- `Expresso.Presenter.Interpreter` is the reference interpreter. The ExUnit tests run it.
- `Expresso.Presenter.Help` makes the rows of the list of keys.

The TypeScript part is under `assets/src/`. It has these modules:

- `deck.ts` reads the list of the steps, which the section below describes.
- `program.ts` reads the program of the presenter, and it trusts the renderer.
- `interpreter.ts` runs the program. It applies one event to the state, and it does not
  touch the document.
- `state.ts` holds the state: the index of the current step, the view, the black screen,
  the digits of a slide number and `undim`, the dimming of code. It also holds the
  messages between the windows, and the side of a click and the direction of a swipe.
- `speaker.ts` makes the texts of the speaker view.
- `dom.ts` reads the document. It applies a state with the projections of the program,
  and it shows the slide of the current step with the inline `style.display` property and
  the `data-step` attribute.
- `main.ts` connects the modules. It sends each event to the interpreter, and it writes
  the fragment of the address.
- `layout.ts` makes the layout check of `?check`. It shows each step with `dom.ts`, it
  measures the elements of the slide, and it writes a report into the document.

The first slide is slide 1, and the first step is step 1. `docs/overlays.md` gives the
rules of a step.

### The list of the steps

`Expresso.Steps` makes a list of each step of the deck, and the renderer writes it as JSON
into the element `script#expresso-deck`. The element comes before the presenter bundle, so
the script can read it at load. The list holds the values that the script needs from the
deck:

- `steps` has one entry for each step of each slide, in sequence. An entry gives the
  slide, the step, `fraction`, `done` and the position text of the speaker view. The
  position text ends with the label of the step, when the step has one.
- `slides` has one object for each slide. It gives the index of step 1 of the slide in
  `steps`, the number of steps and the kind of the transition.
- `duration_ms` gives the length of the talk in milliseconds, or `null`.

The state holds the index of the current step in `steps`. A move forward adds 1 to the
index, and a move back subtracts 1. Each other value comes from the entry at the index, so
the script calculates nothing from the deck. The script trusts the list, as it trusts the
program of the next section. `validateDeck` in `assets/test/validate.ts` decodes each
list of the fixture file.
`docs/research/elixir-presenter-report.md` gives the reason for the list.

### The program

The renderer writes the program of the deck as JSON into the element
`script#expresso-program`, after the list of the steps. The program holds the first state
and the modes. For each key, click and swipe, `run` in `interpreter.ts` does these steps:

1. It finds the first mode whose condition the state matches. For example, the mode
   `blank` matches a state with a black screen.
2. It finds the commands of the event in that mode.
3. It applies the commands to the state, one after the other.

A command changes a field of the state, goes to a step or a slide, or calls a built-in
function. The built-in functions are `open_speaker`, `fullscreen`, `reset_timer` and
`switch_scheme`, and `main.ts` calls them. `main.ts` stops the default operation of the browser when the state
changes or when the event calls a built-in function. The fragment of the address and the
messages between the windows do not go through the modes.

A new key with the current commands is therefore a change to `Expresso.Presenter.Default`
only. Only this module uses the DSL, and a deck cannot change the keys. The TypeScript
interpreter must return the result of the Elixir interpreter.
`assets/test/interpreter.test.ts` runs the fixtures of the Elixir interpreter, and
`docs/development.md` tells how to write them again.
`docs/research/elixir-presenter-report.md` gives the reason for the design.

The script trusts the program, because the renderer writes the program and the script
into the same document. `parse` in `program.ts` makes maps and objects of the JSON, and it
examines no value. These parts find a defect of the program:

- `Expresso.Presenter.Verifier` examines the definition when it compiles.
- The property tests of `Expresso.Presenter.SchemaTest` make random decks. They make sure
  that the program and the list of the steps for each deck agree with
  `Expresso.Presenter.Schema`.
- `validate` in `assets/test/validate.ts` decodes each program of the fixture file with
  the decoders of `assets/src/schema.ts`. It runs only in the tests, and the bundle does
  not hold it.
- The interpreter throws for a command that it does not know.
- The click handler reads commands only from a link of the `goto` option, from a page of
  the overview and from a row of the menu. Thus the script does not run an attribute
  `data-commands` from the HTML of a deck.

`Expresso.Presenter.Schema` describes each value that Elixir writes for the script, and
`assets/src/schema.ts` holds the TypeScript type and the decoder of each value. A test
writes that file from the schema, so the types of the script and the forms of Elixir
cannot differ. The script decodes only the message from the other window, because that
value comes from outside the document. `docs/development.md` tells how to write the file
again.

### The projections

A **projection** is a rule that writes one part of the state to the document.
`Expresso.Presenter.Default` declares each projection, and the program holds them. After
each change of the state, `apply` in `dom.ts` writes them:

| Projection | Example | Effect |
| --- | --- | --- |
| `attribute` | `attribute :blank, "data-blank", flag: true` | A field of the state in an attribute of the `body`. With `flag: true`, the attribute is present only while the field is true. |
| `property` | `property "--fraction", :fraction` | A value of the current entry of the list of the steps in a custom property of the `body`. |
| `mark` | `mark "data-selected", ".handout-page[data-thumbnail]", :slide, [{"", :selected, 0}]` | An attribute on each element of a selector whose `data-slide` or `data-index` agrees with a field of the state plus an offset. |

The style sheet reads each of these attributes and properties. A new attribute of the
state is therefore a change to `Expresso.Presenter.Default` and to the style sheet, and
the script does not change. `Expresso.Presenter.Verifier` refuses a projection with an
unknown field or a wrong name.

The renderer writes each part that does not change during the talk. Examples are
`data-thumbnail`, the sizes of the overview and the four elements of the speaker view.
The script still writes the parts that need the document: the slide of the current step,
the list of keys of the mode, and the texts of the speaker view.

### The options sync and reset

Two options of `Expresso.Presenter.Default` tell what happens to a field outside the
commands:

| Option | Example | Effect |
| --- | --- | --- |
| `sync` | `sync [:blank, :undim]` | The message to the other window holds these fields, after the slide and the step. The other window takes them, and it ignores each other field of the message. |
| `reset` | `reset [:undim]` | Each change of the step gives these fields their first value. A message to another step applies its own fields after the reset. |

The program holds the two lists, and the two interpreters read them. A field with one of
these rules is therefore a change to `Expresso.Presenter.Default` only, and neither
interpreter changes. Neither option can name `index`: the message always holds the slide
and the step, and a change of `index` starts the reset.

### The tests and the bundle

The unit tests of `assets/test/` test these modules with no browser. The browser tests of
`test/e2e/` open a rendered deck in Chromium and operate the presenter with its keys, with
the mouse and with a finger. `docs/development.md` gives both.

`Mix.Tasks.Compile.Presenter` bundles these modules with esbuild into one minified script,
`priv/static/presenter.js`. The compiler runs in front of the Elixir compiler, and Git does
not hold the bundle. The module is in `mix.exs`, because Mix runs the compilers before it
compiles `lib/`. `docs/typescript.md` gives the design.

### The keys

`Expresso.Presenter.Default` holds the keys of each mode. The list of keys that `?` or `/`
shows comes from it, and so do the tables of keys in `README.md`. `Expresso.Test.KeyTables`
writes each table between two comments, such as `<!-- keys present -->` and
`<!-- /keys -->`. A test fails when a table does not agree with the module. This command
writes the tables again:

```sh
EXPRESSO_KEYS=write mix test test/expresso/presenter/key_tables_test.exs
```

The tables do not give these rules:

- A number that is not a slide has no effect. Each key except a digit and `Enter` removes
  the digits. The projection `attribute :digits, "data-digits"` writes the digits on the
  `body`, and the style sheet shows them in the top right corner. A theme can set
  `--digits-color` and `--digits-background`.
- The key after `b` closes the black screen, and it does nothing more.
- A second `s` shows the window of the speaker view again, and it opens no second window.
- `d` toggles the field `undim`. The projection of the attribute `data-undim` writes it on
  the `body`, and the attribute is present only while the field is true. While the attribute is present, a rule of the style sheet
  sets `--dim` and `--dimmed` to 0 on each element of a code element in the present view.
  The rules of a step select the slide by its id, so this rule needs `!important`. The
  option `reset [:undim]` sets `undim` to `false` at each change of the step, so the next
  step dims the code again. The presenter does not have to press `d` again after an
  answer. See "The options sync and reset".

### The list of keys

The list of keys is a `<dialog>` with a search field. The renderer writes it, and the
script operates it with little code:

- `Expresso.Presenter.Help.groups/1` returns the rows of each mode in groups. The `group`
  option of a `key` or an `event` gives the heading of the row. The renderer writes one
  `<details data-mode>` for each mode, and a heading and a list for each group.
- Each row has `data-words`: its keys, its label and its text, in lower case.
- `?` and `/` set the field `help`. `dom.ts` then marks the section of the current mode
  with `data-current`, opens it and calls `showModal()`. The browser moves the focus to
  the field with `autofocus`, puts the rest of the page behind a backdrop and closes the
  dialog with `Esc` or a click outside it (`closedby="any"`).
- The `close` event of the dialog sets `help` to `false`, so the state agrees with the
  browser.
- `search.ts` hides each row whose `data-words` does not hold the typed text, and opens
  each section with a match. The style sheet hides a group or a section with no row that
  shows, and shows the line "No key matches the search." when no row shows.
- The keydown handler of `main.ts` ignores a key in an `input`, a `textarea`, a `select`
  or an element with `contenteditable`. Thus the text in the field does not operate the
  deck.

The field has `type="text"` and `role="searchbox"`. A field with `type="search"` clears its
text at the first `Esc`, and the dialog then stays open.

`f` calls the full screen functions of the browser, and `Escape` of the browser also takes
the document out of full screen.

### The mouse and the touch screen

A click or a tap on the right two thirds of the window shows the next step, and on the
left third the previous step. A swipe of one finger to the left shows the next step, and
to the right the previous step. `side` and `swipe` in `state.ts` return the side of a
click and the direction of a swipe, and the program holds the commands of each. As a key
does, a click first closes a black screen or the list of keys. The handout view scrolls
with a finger, so there a click or a swipe does no more.

`main.ts` listens for `click`, `touchstart` and `touchend`. A swipe does not give a
`click`, so one movement does not move two steps. A click goes to the browser in these
cases:

- it has a modifier;
- it is not the main button;
- it ends a selection of text;
- it is on a link, a button or a form field. A link of the `goto` option is not such a
  link, and the next section gives its rules.

### The links

The `goto` option of a text area, an image or an item makes the element a link to a slide
and a step. `docs/reference/goto-option.md` gives the option for the user.
`Expresso.Goto` holds the value of the option, and `Expresso.GotoVerifier` refuses a
link to a slide or a step that the deck does not have. A link can name its slide by number
or by name. The verifier refuses a name that no slide has or that two slides have, and
`Expresso.Goto.resolve/1` replaces each name with the number of its slide.

The render function of the element puts its content into an `a` element with the class
`goto`. The `href` attribute holds the fragment of the step, such as `#5.2`.
`Expresso.Goto.resolve/1` writes the commands of the link into `data-commands`, such as
`[["goto",7]]`. The number is the index of the step in the list of the steps.

A click on an element with commands runs the commands only in a mode with the option
`element`. The interpreter puts the `each` commands of the mode in front of them:

| Mode | Effect of a click on a link |
| --- | --- |
| `blank` and `help` | The `any` commands close the black screen or the list of keys. |
| `overview` | The style sheet stops a click on the content of a page, so the click finds the page and runs the commands of the page. |
| `present` | The commands of the link, after the command that removes the typed digits. |
| `speaker` | The mode has no option `element`, so the click moves one step. |
| `handout` | The mode has no binding for a click, so the browser follows the `href`. |

`main.ts` stops the default operation of the browser when the program changes the state.
Therefore the browser does not follow the link, and the history gets no entry. A link can
only go to a slide and a step, so the handout view and the print show each state that a
link can give.

### The list of keys

`Expresso.Presenter.Help` makes the rows of the list of keys from the bindings of the
definition. The interpreter runs the same bindings, so the list shows each key that
operates, and no other key. A binding of a click or a swipe has a label, and the list
shows the label in place of a key.

The renderer writes one list for each mode into the element `help`. Each list has the name
of its mode in `data-mode`, and the renderer hides it. `helpMode` in `interpreter.ts`
finds the mode under the list of keys, and `dom.ts` shows only the list of that mode. The
style sheet shows the element while the `body` has `data-help`. A printer does not get the
list.

### The progress bar

The progress bar is the element `progress` at the bottom of the present view. The
renderer writes it into each document. It also writes `data-progress` on the `body` from
the metadata of the deck: `false` for `progress: false`, and `true` otherwise. The program
of the deck holds the same value as the first value of the field `progress`, and `g`
changes the state.

The `fraction` of the current entry of the list of the steps is the part of the deck
before the current step. Each step of each slide counts one time, so the bar is full at
the last step only. The projection `property "--fraction", :fraction` writes that part
into `--fraction` on the `body`, and the style sheet sets the width of the bar from it.
The style sheet shows the bar in the present view only, and not on a black screen, in the
overview or on paper. Its color is `--accent`, and a deck can set `--progress-color` and `--progress-height`.

### The transitions

The `transition` option of the deck gives the transition from one slide to the next in the
present view: `:fade`, `:slide`, `:zoom`, `:none` or a transition of the CSS of the deck.
The default is `:fade`. A slide can have the same option, and
`Expresso.Slide.put_options_in_metadata/1` puts it into the metadata of the slide. The list
of the steps gives the kind of each slide. The slide option comes first, then the deck
option, then `fade`. `Expresso.Steps.kind/1` writes each underscore of the name as a
hyphen, as the renderer does for an effect.

`transition` in `interpreter.ts` decides if a change of state has a transition. Only a
move to a different slide in the present view has one. A change of the step, a black
screen, the overview and the list of keys have none. A transition belongs to the border
between two slides, so the slide with the higher number gives the kind in the two
directions. A move forward uses the kind of the next slide. A move back uses the kind of
the slide that it leaves, and the direction `back` plays it in reverse.

`animate` in `dom.ts` writes `data-transition` and `data-direction` on the `html` element,
and it applies the new state inside `document.startViewTransition`. The browser runs the
update later, so the update reads the state of that time. A browser without the API, and a
reader who asks for reduced motion, get the update at once. The browser tests ask for
reduced motion, so a key in them changes the page at once.

Only the element `screen` of the present view has a `view-transition-name`, and the root has
none. Therefore the progress bar and the other fixed parts do not move with the slide. The
style sheet gives each kind its keyframes on the pseudo-elements
`::view-transition-old(slide)` and `::view-transition-new(slide)`. `fade` uses the
animations of the browser. A theme can set `--transition-dur`.

The set of kinds is open, with the same model as the effects. A kind is a name and some CSS
rules, and the presenter does not know the names:

- `Expresso.Css.scan/1` finds each name of a rule for `html[data-transition="..."]`.
  `Expresso.Theme.transitions/0` gives the names of the theme, with `fade` and `none`,
  which need no rule.
- `Expresso.TransitionVerifier` makes sure that the transition of the deck and of each
  slide has a rule in the theme or in the CSS of the deck. Without the verifier, a wrong
  name fades with no error.
- The schema of the program gives a kind as a string of letters, digits and hyphens.
  `decodeKind` of `schema.ts` therefore takes a kind of the deck. It refuses a value that
  the renderer does not write, such as `wipe_down`.
- `Expresso.Presenter.Schema.transitions/0` gives the built-in kinds only. A test makes sure
  that they agree with the rules of the theme.

A deck struct from data does not go through the verifier, so a kind without a rule fades.

### The overview

The overview shows the page of the last step of each slide in a grid. The state holds
`overview` and `selected`, the number of the selected slide. `o` opens the overview, and
it selects the current slide. While the overview shows, the state matches the mode
`overview`. The interpreter then finds only the bindings of that mode, and the list of
keys of the overview shows only these bindings.

`j`, `k`, the arrow keys, `Home` and `End` select a different slide. A key that selects a
slide outside the deck has no effect. `Enter` and a click on a slide close the overview
and go to step 1 of the slide. The page of the last step of each slide holds these
commands in `data-commands`, and a click on the page runs them. `o` and `Escape` close the
overview, and the step does not change.

`Expresso.Presenter.Program.columns/1` returns the number of columns: the square root of
the slide count, or the next larger integer. The number of rows is then not more than the
number of columns. The program uses the number for `ArrowUp` and `ArrowDown`. The renderer
writes `data-thumbnail` on the page of the last step of each slide, and
`--overview-columns` and `--overview-zoom` on the `body`. The style sheet scales each page
with `zoom`. A mark writes `data-selected` on the thumbnail of the selected slide. The
padding and the gaps of the grid are 1vw wide and 1vh high, so the grid of each deck fits
in the window.

In the speaker view, the overview replaces the grid of the speaker view while it shows. A
deck can set `--overview-color` for the outline of the selected slide, which has the color `--accent`.

### The menu

The menu lists each slide with a small copy of its last step, and a row for each step
under it. A row of a step shows the number and the label of the step. See "Step labels"
in `docs/reference/step-labels.md`. The overview shows the slides and the menu shows the
steps, so the two have different keys: `o` and `m`.

The state holds `menu` and `cursor`, the index of a step. `m` opens the menu with
`copy(:cursor, :index)`, so the cursor starts at the current step. While the menu shows,
the state matches the mode `menu`:

- `j` and `k` run `move(:cursor, 1)` and `move(:cursor, -1)`. A move past the first step
  or the last step makes no change.
- `Enter` runs `go(:cursor)`, which goes to the step of the cursor, and it closes the menu.
- A click on a row runs the commands of the row, which go to the step and close the menu.
  The row of a slide goes to step 1 of the slide.
- `m` and `Escape` close the menu, and the step does not change.

The step of the audience changes only at `Enter` or at a click. `menu` and `cursor` are
not in the option `sync`, so the menu shows only in the window that opens it, as the
overview does.

The renderer writes the menu in `nav#menu`. The copy of a slide is a `section` with
`data-step` at the last step, so the overlay rules show that step, as they do on a page of
the handout view. The copy is as large as the window, and `--menu-zoom` scales it. A
frame of an embed in a copy gets no source, so a copy shows the fallback.

Two marks write `data-cursor` and `data-current` on the rows of the steps. The mark of the
cursor has `scroll: true`, so the script scrolls its row into the view of the menu after
each change. A slide with one step and no label gets `data-single` on the row of its step,
and the style sheet puts that row over the row of the slide. A deck can set `--menu-color`
for the marks, which have the color `--accent`.

### The handout view

The handout view knows only `j`, `k`, `p`, `a`, `?` and `/`. `j` and `k` change the state, and
`p` then shows that step in the present view. The browser keeps each other key, so the
arrow keys and the space bar scroll the pages. A key with the Control, Alt or Meta
modifier always goes to the browser. `main.ts` stops the default operation of a key only
when the key changes the state or calls a built-in function.

### The speaker view

The speaker view is the same document in a second window, with `?speaker` in the address.
It shows two pages of the handout view: the page of the current step and the page of the
next step. A mark writes `data-speaker` on these two pages, and the style sheet puts them
in a grid and scales them with `zoom`. The notes of the current page, the position and a
timer go into three elements that the renderer writes into the handout view. The style
sheet hides them in each other view and on paper. The speaker view knows the keys of the
present view, but `p` and `s` have no function in it. `r` sets the timer back to `0:00`,
and the timer then starts at the next change of the step.

The `duration` option of the deck gives the length of the talk in minutes. The list of the
steps gives it in milliseconds, and `?duration=` in the address replaces it with a number
of minutes. `talkLength` in `speaker.ts` reads the two values. The renderer writes a
fourth element of the speaker view, `speaker-left`, and the speaker view writes the time
left into it. `pace` gives its value of `data-pace`: `on`, `behind` or `over`. For a talk
with no length, the element has no text, and the style sheet hides it.

The pace compares the time used with the `done` of the current entry: the part of the
steps before the current step. The speaker is `behind` when the time used is more than one minute longer than
that part of the time. `done` is not `fraction`, because `fraction` is 1 at the last step,
and the last step also needs its part of the time. The time left goes up to the next full
second, so the timer and the time left always give the length of the talk.

### The messages between the windows

Each window sends its position to the other window with `postMessage`. The message holds
the slide, the step and the fields of the option `sync`. Thus `b` in the speaker view
gives a black screen to the audience, and `d` changes the code of the audience. The
message also holds the variant of the theme that `t` chose. See "Two variants of a
theme". A window accepts a message only from the other window. The present view
gets the speaker view from `window.open`, and the speaker view gets the present view from
`window.opener`. After a reload of the present view, the next message of the speaker view
makes the connection again. `BroadcastChannel` is not in this design, because a browser
can give no shared origin to a document that it opens from a file.

A window sends only the changes of its own keys and of its own address, and each message
holds the time of the change. A change of another part of the state, such as the overview or
the list of keys, sends no message. For this reason, the overview shows only in the window
that opens it. A window does not send a position from the other window back, and it ignores
a message that is older than its own state.

At the same time, the speaker view takes the state of the present view, so the two windows
always end at the same state. Both windows read the same clock, so the time orders the
changes of both, also after a reload.

Before this rule, each window sent each position back. Two keys that came faster than a
message then gave a loop. The echo of the first key came back after the second key. The
two windows then sent the two positions to each other with no end.

### The address

The fragment of the address holds the slide and the step, such as `#4.2`. `main.ts` reads
it at load and at each `hashchange` event. It writes the fragment with
`history.replaceState` after each change, so the history of the browser gets no entry for
a step. A fragment that gives no slide and step of the deck has no effect. `#4` is step 1
of slide 4.

The query of the address gives options of the window: `?speaker`, `?all`, `?check`,
`?duration=` and `?scheme=`. `main.ts` reads them at load only, and it does not write them.

### The print

A printer gets the handout view, because a `@media print` block selects it. The key `p` is
not necessary for a printer. It makes the handout view available on a screen, and a
screen reader then reads each page of it.

The `handout` option of a slide selects the steps that get a page in the handout view and
on paper, such as `handout [2, :last]`. The `handout` option of the deck gives `:all` or
`:last` to each slide without the option, and its default is `:all`. `Expresso.Handout`
gives the forms and the steps. The renderer still writes a page for each step, because
the speaker view shows the page of each step. It writes `data-omit` on each page that the
option does not select.

The style sheet hides such a page in the handout view and on paper. The handout view on a
screen therefore shows the pages that a printer prints.

The key `a` of the handout view changes the `every` field of the state, and a projection
writes it into `data-every` on the `body`. With `data-every="true"`, the style sheet shows
each page in the handout view and on paper. A print then gets every step, whatever the
`handout` options select. The field stays in one window, and a print from the speaker
view gets the selection.

`?all` in the address gives the field the value `true` at load. A print with no key, such
as the `--print-to-pdf` option of Chromium with no window, then gets every step. The key
`a` can still change the field. The speaker view opens with the address of the present
view, so it keeps `?all`.

Each page that shows, except the first, starts a new sheet with `break-before`. With
`data-every="true"`, each page except the first does. A rule of `break-after` on the last
page cannot do this, because the last page of the document can be a page with
`data-omit`. The print block also hides the four elements of the speaker view, so a print
from that window gives the same pages.

A page of the handout view takes the full height of the screen, or of the paper. The
print block gives the paper a landscape orientation, because a slide is wider than it is
high. Therefore each page keeps the proportions of a slide.

### The layout check

`?check` in the address runs the layout check of `layout.ts`. `docs/reference/layout-check.md`
gives what it finds. These are the reasons for its design:

- **It runs in the browser.** Only a browser engine knows the place of each element,
  because the place depends on the fonts, the style sheet and the size of the window. The
  compiler and the binary have no browser engine. A headless Chromium can still run the
  check with no window, so a continuous integration job can use it.
- **It measures the window, and not the slide.** Content past the edge of the window can
  make the slide larger too. The window is the part that the audience sees.
- **It measures the text, and not the box.** A text box is as wide as the slide. When it
  moves, its box goes past an edge, and its text can stay in the window. The check
  therefore measures the text and the content of each element, such as an `img` or a
  `pre`.
- **It sets the time of each animation to zero.** The check reads the final place of each
  element at each step. With an animation, the check would read a place during the
  animation.
- **It measures each step.** An `on` entity can move an element past an edge at one step
  only. A hidden element keeps its space, so most problems show at each step. The report
  gives each problem at its first step only.
- **It names the innermost element.** A formula that is too wide also makes its column
  and its `columns` element too wide. The innermost element is the one to correct.
- **It reads `offsetHeight` for a line of code.** An `on` entity can turn a code element,
  and a turned box has a larger bounding box. `offsetHeight` does not change with a
  transform, so a turned line with no break counts as one line.

## The build

The repository gives a Nix shell. `flake.nix` and `shell.nix` give Erlang/OTP 29, Elixir
1.20, Node 24 and Zig 0.16. `flake.nix` pins `nixpkgs` to one commit, so the shell gives
the versions of `.tool-versions`. Burrito needs Zig for the binary, and Zigler needs it
for the GIF encoder of `tools/`. `package.json` gives Prettier, the other tools of the
presenter script, and the Playwright driver. The `.tool-versions` file gives the
same versions for a different tool manager, and `.claude/hooks/session-start.sh` gives them
to a remote session.

Each dependency comes from Hex, except Shoddy. Shoddy gives the functions for results,
lists, maps and keyword lists, such as `Shoddy.Result.collect/2` for the transformer and
the verifiers. It comes from the `main` branch on GitHub, and the lockfile gives the
commit. `docs/development.md` tells how to update it.

The commands are:

- `mix deps.get` gets the dependencies.
- `mix expresso examples/demo.exs out.html` makes an HTML document.
- `mix check` runs the curated tools of `ex_check`. These include the compiler, the
  formatter, Credo, Doctor, Dialyzer, Sobelow and ExUnit. `.check.exs` gives the
  configuration. It makes a compiler warning an error, and it lets Sobelow read the skip
  comments. It also runs `mix hex.audit` and the browser tests, and it makes the binary for
  the target of the computer and runs the release tests.
- `mix expresso.gifs` records the GIFs and the stills of the example decks. The task,
  `Expresso.Recorder` and `Expresso.Gif` are in `tools/`, which only dev and test
  compile. `docs/development.md` gives the details.
- `mix release expresso_cli_app` makes a binary with Burrito. The targets are macOS and
  Linux, for x86_64 and for aarch64. Burrito needs Zig 0.16.0 and `xz` on the path.
  `shell.nix` pins the Zig version, and `mix.exs` must agree with it.
- `mix test --only release` runs the binary, and `EXPRESSO_BINARY` gives its path.
  `docs/development.md` gives the commands.

## Open work

The list has no item at this time. The last item, the dim state of `docs/dim-state.md`,
gave each role of text its own dimmed color.

`docs/overlays.md` gives the design of the overlays, and the code contains each part of
it. `.github/workflows/check.yml` runs each check for a pull request in parallel jobs, on
the versions of `.tool-versions`.
