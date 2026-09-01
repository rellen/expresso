# Architecture

This document tells you how Expresso makes an HTML document from a deck. It gives the
structure of the code at this time. It also names the parts that are not complete.

## The two input paths

Expresso has two ways to make an `Expresso.Deck` struct. Both paths reach HTML.

### The imperative path

A script builds a deck with function calls, and the script returns the deck.

```elixir
Expresso.Deck.new("demo")
|> Expresso.Deck.add_slide("heading_with_text_box", %{heading: "This is a heading"}, [
  Expresso.Element.TextBox.new("This is a text-area inside a text-box.")
])
```

`Expresso.main/2` reads a file of this kind. The section "The render pipeline" gives the
steps.

### The DSL path

A module declares a deck with the Spark DSL. The script returns the module.

```elixir
defmodule Expresso.Example do
  use Expresso

  name("my presso")

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
struct with an empty metadata map, and it numbers the slides with
`Expresso.Deck.number_slides/1`.

The DSL gives no heading for a slide. The `slide` entity has a `name` option only. The
default slide template writes the heading container only when the metadata contains a
heading. Therefore a slide from the DSL shows its elements without a heading.

A heading option for the `slide` entity is open work.

## The render pipeline

`Expresso.main/2` does these steps:

1. `File.stat/1` makes sure that the input file is present.
2. `Code.eval_file/1` evaluates the input script.
3. `Expresso.to_deck/1` makes an `Expresso.Deck` struct from the value of the script.
4. `Expresso.Deck.render/1` makes the HTML.
5. The function writes the HTML to the output file, or to the standard output.

The function has a clause for `nil` in front of these steps. `Mix.Tasks.Expresso` and
`Expresso.BurritoEntryPoint` read the input path with `Enum.at/2`, which gives `nil` for
a command with no argument. The clause writes the usage text and returns an error tuple.

`Expresso.to_deck/1` accepts three values:

| Value | Operation |
| --- | --- |
| An `Expresso.Deck` struct | The function returns the struct. |
| A module that uses the DSL | The function calls `Expresso.parse/1`. |
| The tuple of a `defmodule` expression | The function reads the module from the tuple. |

A script that ends with a `defmodule` expression returns the third value. Therefore a script
that declares a deck module needs no other line.

`Expresso.to_deck/1` reads `spark_is/0` to know a module of the DSL. Spark writes this
function into each module that uses `Expresso`. For a different value the function returns
an error tuple, and `Expresso.main/2` writes the message.

`Expresso.Deck.render/1` does these steps:

1. `Expresso.load_templates/0` compiles each file in `./priv/templates/decks/` and in
   `./priv/templates/slides/`.
2. `Expresso.Renderer.render/1` makes an HTML tree with Temple.
3. `Phoenix.HTML.safe_to_string/1` makes a string.
4. `Floki.parse_document!/1` and `Floki.raw_html(pretty: true)` format the string.
5. The function puts `<!DOCTYPE html>` and a newline in front of the string.

The wildcard of step 1 is relative to the working directory of the command. This
repository has no `priv/templates/` directory, so step 1 compiles no file here. A deck
that needs a custom template gives a module instead. See "The templates".

Step 5 is necessary because Floki drops a doctype node. Therefore the renderer cannot
write the doctype, and the deck function adds it after step 4. Without the doctype a
browser uses the quirks mode, and the layout is not correct.

Two entry points call `Expresso.main/2`:

- `Mix.Tasks.Expresso`, for the command `mix expresso <input> [output]`.
- `Expresso.BurritoEntryPoint`, for the binary that Burrito makes.

## The document

`Expresso.Deck.render/1` writes one HTML document with this structure. Each part below
the doctype comes from `Expresso.Renderer.render/1`:

```
<!DOCTYPE html>
html
  head
    title            the name of the deck
    style            assets/fonts.css
    style            assets/style.css
    body
      div            one flex container for all the slides
        section      one for each slide, class "slide", id "slide-<number>"
          div        the header, from the deck template
          div        the body, from the slide template
          div        the footer, from the deck template
      script         assets/main.js
```

The renderer holds the three asset files in module attributes. It reads them with
`File.read!/1` at compile time. Each file is an `@external_resource` of the module.
Therefore a change to an asset file starts a new compile of `Expresso.Renderer`.

The renderer writes an inline `style` attribute on each `section`. The first slide gets
`display: flex`, and each other slide gets `display: none`.

The container `div` gets `height: 100vh`, and each `section` gets `height: 100%`. The
viewport unit is necessary because the `body` gets `min-height`, and a percentage height
cannot resolve against a minimum height. With `height: 100%` on the container, each slide
takes the height of its content only.

## The templates

A template makes the HTML for a part of the document. There are two kinds.

A deck template gives a header and a footer. It implements the `Expresso.Template.Deck`
behaviour, which has the callbacks `header/1` and `footer/1`.

A slide template gives the body of a slide. It has a `render/1` function.

`Expresso.Template` selects a template from the metadata. A slide template comes from
`slide.metadata[:template]`, and a deck template comes from `deck.metadata[:template]`.
The default value of each is `{:builtins, :default}`. The private function
`module_from_template_definition/2` maps this value to a module name.

The value takes one of two forms. The tuple `{:builtins, name}` selects a built-in template.
A module selects that module. Therefore a template that `Expresso.load_templates/0` compiles
from `./priv/templates/` is available as a module.

These two lines show each kind:

```elixir
Expresso.Deck.new("my deck", %{template: MyDeckTemplate})
|> Expresso.Deck.add_slide("first", %{template: MySlideTemplate}, [])
```

The DSL gives no template option. A deck from the DSL uses the built-in templates.

## The elements

An element is the content of a slide. `Expresso.Element.TextBox` and
`Expresso.Element.TextArea` are the two elements at this time.

An element module has these parts:

- A struct with a `__spark_metadata__` field.
- A `get_assigns/1` function. It makes a map of assigns from the struct.
- A `render/1` function. It makes the HTML from the assigns.

`Expresso.Template.render_elements/1` matches `%module{}` for each element. It then calls
`module.get_assigns/1` and `module.render/1`. There is no `@behaviour` for an element, and
the compiler does not make sure that a module has the two functions.

A `text_box` contains other elements. A `text_area` contains text. The renderer writes the
text with `Phoenix.HTML.raw/1`, so the text can contain HTML.

## The DSL

`Expresso.Extension` gives the Spark extension. It contains one section, `deck`, which is a
top level section. The section holds `slide` entities. A `slide` holds `text_box` entities,
and a `text_box` holds `text_area` entities.

The extension has an empty `imports` option and an empty `transformers` option. It has no
verifiers.

The `slide` entity takes an optional name as its first argument. The DSL accepts `slide do`
and `slide "name" do`.

## The presenter

`assets/main.js` controls the document in the browser. It holds one number, the number of
the current slide. The first slide is slide 1. The code shows a slide and hides a slide with
the inline `style.display` property.

The keys are:

- `j` shows the next slide.
- `k` shows the previous slide.
- `p` shows all the slides, for a printer.

## The build

The repository gives a Nix shell. `flake.nix` and `shell.nix` give Erlang 28, Elixir 1.20,
Node 24, Prettier and Zig 0.16. Zig is a dependency of Burrito. The `.tool-versions` file
gives the same versions for a different tool manager.

The commands are:

- `mix deps.get` gets the dependencies.
- `mix expresso examples/demo.exs out.html` makes an HTML document.
- `mix check` runs the curated tools of `ex_check`. These include the compiler, the
  formatter, Credo, Doctor, Dialyzer, Sobelow, MixAudit and ExUnit. `.check.exs` gives the
  configuration. It makes a compiler warning an error, and it lets Sobelow read the skip
  comments.
- `mix release expresso_cli_app` makes a binary with Burrito. The targets are macOS and
  Linux, for x86_64 and for aarch64. Burrito needs Zig 0.16.0 and `xz` on the path.
  `shell.nix` pins the Zig version, and `mix.exs` must agree with it.

## Open work

This list gives the work in the order of its value. Take the first item that you can do.

### 1. Answer the open decisions for overlays

`docs/overlays.md` ends with four open decisions. Answer them before you write code for
overlays, because each answer changes the DSL.

Answer the decision about the `class` option first. CSS cannot add a class name to an
element, so the `on` entity cannot apply a class with a generated rule. The three options
are: remove the `class` option, let the JavaScript code apply the class names, or use a
CSS style query. The document gives a proposal for each decision. The maintainer decides.

### 2. Write the code for overlays

The section "Changes to the current code" in `docs/overlays.md` lists each change, and the
section "The test plan" lists each test. This work is the largest item in this list.

### 3. Give a heading to a slide of the DSL

The `slide` entity has a `name` option only. A deck from the DSL shows no heading, because
the default slide template reads the heading from the metadata. Add a `heading` option to
the entity, and write it into the metadata in `Expresso.parse/1`.

### 4. Raise the coverage that `mix doctor` measures

`mix doctor` does not pass. The moduledoc coverage is 100 percent, but the doc coverage
and the spec coverage are each 51.9 percent.

Twelve functions of this project have no `@doc`, or no `@spec`, or neither:

- `Expresso.Slide.get_assigns/1`
- `Expresso.Renderer.render/1`
- `Expresso.Template.render_elements/1`
- `Expresso.Element.TextBox.new/1`, `get_assigns/1` and `render/1`
- `Expresso.Element.TextArea.new/1`, `get_assigns/1` and `render/1`
- `Expresso.Builtins.Templates.Decks.Default.header/1` and `footer/1`
- `Expresso.Builtins.Templates.Slides.Default.render/1`

The count of the tool is larger than twelve, because `use Spark.Dsl` writes ten more
public functions into `Expresso`, and `use Temple.Component` writes more into each
element. Examples are `Expresso.init/1` and `Expresso.opt_schema/0`. You do not write
these functions, and a `@doc` for them is not possible in the usual way. Therefore make
sure that the tool can pass before you start. `mix doctor` reads `.doctor.exs`, which this
repository does not have, and that file can remove a module from the report.

### 5. Smaller items

- `Expresso.present/0` raises an error with the text "not implemented".
- `examples/hello_world.exs` needs the expresso package on Hex, which has no release at
  this time.
- The repository has no continuous integration. No check runs on a pull request. Each
  result in this repository comes from a command that a person or a session ran.
- No session compiled this project on the versions of `.tool-versions`. A container gives
  Erlang/OTP 25 and Elixir 1.18. See `docs/development.md`.
