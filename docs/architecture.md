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
struct with an empty metadata map, and it numbers the slides with
`Expresso.Deck.number_slides/1`.

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
heading from the metadata, as they do for a slide from `Expresso.Deck.add_slide/4`.
Therefore `Expresso.parse/1` calls `Expresso.Slide.put_options_in_metadata/1` for each
slide, and that function puts the heading into the metadata. The default slide template
writes the heading container only when the metadata contains a heading.

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
    style            assets/fonts.css, with the bytes of each font file in it
    style            assets/style.css
    style            the generated rules of the overlays, from Expresso.Overlay.Render
    body           data-view "present"
      div            the present view, class "screen"
        section      one for each slide, class "slide", id "slide-<number>",
                     data-step "1", data-max-step from the slide
          div        the header, from the deck template
          div        the body, from the slide template
          div        the footer, from the deck template
      div            the handout view, class "handout"
        section      one for each step of each slide, class "handout-page",
                     data-step from the step, data-slide from the slide
          div        the same three parts as a slide of the present view
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
service looks correct on the machine of the author, and it loses the font at a conference
with no network. It also gives the address of each person who reads the deck to that
service.

Atkinson Hyperlegible is the font, and the Braille Institute of America gives it under the
SIL Open Font License, Version 1.1. `assets/fonts/OFL.txt` holds that license, and the
license permits this use. The eight files take approximately 110 kilobytes, and the data
URIs take approximately 147 kilobytes of the document.

The renderer holds the two style sheets and the presenter bundle in module attributes.
It reads them with `File.read!/1` at compile time. Each style sheet, and each source of the
bundle under `assets/src/`, is an `@external_resource` of the module. Therefore a change to
one of these files starts a new compile of `Expresso.Renderer`. Elixir compares the content
of an external resource, and not its time, so a `touch` does not start a compile.

`Expresso.Theme` reads `assets/style.css` in the same way. It gives the names of the custom
properties of the theme to `Expresso.Overlay.PropertyVerifier`, and `docs/overlays.md`
gives the warnings of that verifier.

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

An element is the content of a slide. `Expresso.Element.TextBox`,
`Expresso.Element.TextArea` and `Expresso.Element.Image` are the three elements at this
time.

An element module has these parts:

- A struct with a `__spark_metadata__` field, and with the `at`, `on`, `steps` and `el`
  fields of the overlays.
- A `get_assigns/1` function. It makes a map of assigns from the struct. The key `overlay`
  holds the attributes from `Expresso.Overlay.Render.attributes/1`.
- A `render/1` function. It makes the HTML from the assigns, and it puts the `overlay`
  list on the root tag with `rest!: @overlay`. An element that writes text from the deck
  puts that text in one block element inside the root tag.

`Expresso.Template.render_elements/1` matches `%module{}` for each element. It then calls
`module.get_assigns/1` and `module.render/1`. There is no `@behaviour` for an element, and
the compiler does not make sure that a module has the two functions.

A `text_box` contains other elements. A `text_area` contains text. The renderer writes the
text with `Phoenix.HTML.raw/1`, so the text can contain HTML.

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
property, and the width then changes with the step.

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

The theme makes `.text-area` a flex container. Each element inside a flex container is a
flex item, and a flex item also holds each run of text between two elements. Therefore
text with an inline element, such as `<b>`, breaks into more than one line. The render
function of a text area puts the text in one block element, which is one flex item. A
custom element that writes text from the deck must do the same.

## The DSL

`Expresso.Extension` gives the Spark extension. It contains one section, `deck`, which is a
top level section. The section holds `slide` entities. A `slide` holds `text_box` and
`pause` entities, and a `text_box` holds `text_area` and `on` entities. A `text_area`
holds `on` entities. A `slide` and a `text_box` also hold `image` entities. Each element
has an `at` option, and a slide has a `steps` option and an `auto_reveal` option.
`docs/overlays.md` gives the meaning of each.

The extension imports nothing, and it lists three modules:

- `Expresso.Overlay.Transformer` expands the overlay specifications of each slide at
  compile time.
- `Expresso.Overlay.Verifier` reports a specification that breaks a rule.
- `Expresso.Overlay.PropertyVerifier` gives a warning for a custom property that the theme
  does not use.
- `Expresso.Overlay.SizeVerifier` gives a warning for a slide of very many steps.

After the transformer, each element and each `on` entity holds its step numbers in the
`steps` field. The metadata of the slide holds the maximum step number in `max_step`.
`docs/overlays.md` gives the rules.

The `slide` entity takes an optional name as its first argument. The DSL accepts `slide do`
and `slide "name" do`.

## The presenter

The presenter is a TypeScript program under `assets/src/`. `state.ts` holds the number of
the current slide and the number of the current step. It also holds the function that
changes them, and it does not touch the document. `dom.ts` reads the document, and it
applies a state with the inline `style.display` property and the `data-step` attribute.
`main.ts`
connects the two. The first slide is slide 1, and the first step is step 1.
`docs/overlays.md` gives the rules of a step.

`Mix.Tasks.Compile.Presenter` bundles these modules with esbuild into one minified script,
`priv/static/presenter.js`. The compiler runs in front of the Elixir compiler, and Git does
not hold the bundle. The module is in `mix.exs`, because Mix runs the compilers before it
compiles `lib/`. `docs/typescript.md` gives the design.

The keys are:

- `j` shows the next step, or the first step of the next slide after the last step.
- `k` shows the previous step, or the last step of the previous slide at the first step.
- `p` changes between the present view and the handout view.

A printer gets the handout view, because a `@media print` block selects it. The key is
not necessary for a printer. It makes the handout view available on a screen, and a
screen reader then reads each step of each slide.

A page of the handout view takes the full height of the screen, or of the paper. The
print block gives the paper a landscape orientation, because a slide is wider than it is
high. Therefore each page keeps the proportions of a slide.

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
The list holds no item at this time.

`docs/overlays.md` gives the design of the overlays, and the code contains each part of
it. `.github/workflows/check.yml` runs each check for a pull request, and each of the two
pairs of versions of the toolchain passes.

One question has no answer, and the maintainer decides it. The section "The imperative
API" of `docs/overlays.md` asks whether `Expresso.Deck.add_slide/4` keeps parity with the
DSL for an overlay, or whether an overlay needs the DSL.
