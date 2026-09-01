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

Two entry points call `Expresso.main/2`:

- `Mix.Tasks.Expresso`, for the command `mix expresso <input> [output]`.
- `Expresso.BurritoEntryPoint`, for the binary that Burrito makes.

## The document

`Expresso.Renderer.render/1` writes one HTML document with this structure:

```
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

## The templates

A template makes the HTML for a part of the document. There are two kinds.

A deck template gives a header and a footer. It implements the `Expresso.Template.Deck`
behaviour, which has the callbacks `header/1` and `footer/1`.

A slide template gives the body of a slide. It has a `render/1` function.

`Expresso.Template` selects a template with the value of `slide.metadata[:template]`. The
default value is `{:builtins, :default}`. The function
`Expresso.Template.module_from_template_definition/2` maps this value to a module name.

The value takes one of two forms. The tuple `{:builtins, name}` selects a built-in template.
A module selects that module. Therefore a template that `Expresso.load_templates/0` compiles
from `./priv/templates/` is available as a module.

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
  Linux, for x86_64 and for aarch64.

## Open work

- `Expresso.present/0` raises an error with the text "not implemented".
- The repository has no continuous integration. No check runs on a pull request.
- `examples/hello_world.exs` needs the expresso package on Hex, which has no release at
  this time.
- The `slide` entity has no `heading` option. A deck from the DSL shows no heading.
- `mix doctor` does not pass. The moduledoc coverage is 100 percent, but the doc coverage
  and the spec coverage are near 50 percent. Many public functions have no `@doc` and no
  `@spec`.
