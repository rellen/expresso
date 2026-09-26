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
struct, and it numbers the slides with `Expresso.Deck.number_slides/1`. The metadata map
of the deck holds the `progress`, `handout`, `print_notes`, `slide_numbers`, `duration`
and `transition` options of the deck. Their defaults are `true`, `:all`, `true`, `false`,
`nil` and `:fade`.

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
    style            the rules of the token classes of a code element, from Makeup
    style            the generated rules of the overlays, from Expresso.Overlay.Render
    body           data-view "present", data-progress, data-print-notes and
                   data-duration from the deck
      div            the present view, class "screen"
        section      one for each slide, class "slide", id "slide-<number>",
                     data-step "1", data-max-step from the slide,
                     data-transition from the slide or the deck
          div        the header, from the deck template
          div        the body, from the slide template
          div        the footer, from the deck template
            span     the slide number, class "slide-number", with slide_numbers: true
      div            the handout view, class "handout"
        section      one for each step of each slide, class "handout-page",
                     data-step from the step, data-slide from the slide,
                     data-omit when the handout option does not select the step
          div        the same three parts as a slide of the present view
          aside      the notes of the slide, class "notes", when the slide has notes
      div            the progress bar, id "progress"
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
behaviour, which has the callbacks `header/1` and `footer/1`. The footer of the default
deck template is empty. The `slide_numbers` option gives the numbers of the slides.

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
`Expresso.Element.TextArea`, `Expresso.Element.Image`, `Expresso.Element.List` with
`Expresso.Element.Item`, `Expresso.Element.Table` with `Expresso.Element.Row`,
`Expresso.Element.Quotation`, `Expresso.Element.Spacer`, `Expresso.Element.Code` with
`Expresso.Element.Lines`, `Expresso.Element.Columns` with `Expresso.Element.Column`,
`Expresso.Element.Math`, and `Expresso.Element.Diagram` with `Expresso.Element.Part` are
the elements at this time.

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

A `list` holds `item` elements, and an item holds text and one optional nested `list`. The
DSL accepts three levels of lists, because Spark cannot nest two entities inside each
other without a limit. `Expresso.Extension` builds the three levels with a loop. The
`ordered` option gives an `ol` element, and the default is a `ul` element. The `reveal`
option shows the items one after the other, and `docs/overlays.md` gives its rules. The
text of an item goes into one block element, as in a text area, and it can contain HTML.

A `table` holds `row` elements, and a row takes a list of strings as its cells. Each cell
can contain HTML. The `header` option makes the first row the header, and the renderer
then puts it into a `thead` element with `th` cells. The `reveal` option shows the rows
one after the other, and the header row shows with the table. `docs/overlays.md` gives
the rules.

A `quotation` takes its text as its first argument, and the `by` option gives the name of
the source. The renderer writes a `figure` element with a `blockquote` element, and the
source goes into a `figcaption` element. The entity is not named `quote`, because
`Kernel.quote/2` has that name, and a call of the DSL would be ambiguous.

A `spacer` has no content. The theme gives it `flex-grow: 1`, so it takes the free space
of its container and pushes the elements after it to the end. Two spacers around an
element put the element in the middle. Write `spacer()` with parentheses, as for `pause`.

A `code` element shows source code. The entity takes the name of the language as its
optional first argument, and the `text` option holds the source. `Expresso.Highlight`
makes one HTML fragment for each line at render time. Makeup lexes the text when a lexer
package registers the language, and `mix.exs` lists one package for each language:
Elixir, Erlang, Gleam, EEx and HEEx, HTML, CSS, JavaScript and TypeScript, JSON, SQL, C,
Rust and diff. Without a lexer for the language, the fragment is the escaped text. The
rules of the token classes come from a style of Makeup, and the renderer writes them
into the document in their own `style` element.

The `reveal` option of a code element takes a list of line numbers and of ranges, such
as `[1..3, 4..8, 10]`. `Expresso.Element.Code.build/1` makes one `Expresso.Element.Lines`
child for each item, with the specification `[from: :next]`, and the transformer gives
each group its steps as it does for the items of a list. Each line goes into a `span`
element, and a hidden line keeps its space. A line number that is more than the number of
lines of the text gives an error, because such a group shows nothing and it takes one
step of the slide. `docs/overlays.md` gives the rules.

`Expresso.Deck.render/1` writes the document with Floki, and Floki drops a text node that
is only white space. A line of code holds such nodes: an indentation, a space between two
tokens, a line break. Therefore `Expresso.Highlight` puts each white space token into the
span of the token before it, and it puts a zero width space into a line that has no other
character. An element that writes text with significant white space must do the same.

A `columns` element puts its `column` elements side by side, and a column holds the same
elements as a text box. The theme makes the element a flex row. A column without a
`width` option takes an equal part of the free space. A column with the option, such as
`width "30%"`, takes that width: the render function writes the custom properties
`--column-width` and `--column-grow` on the column, and the theme reads them. A column
takes the `at` option and the `on` entity. A column cannot hold a `columns` element,
because Spark cannot nest two entities inside each other without a limit.

A `math` element takes MathML as its first argument, from the `<math>` tag to the
`</math>` tag. A browser renders MathML Core without a script and without a font file,
and each browser of the floor of this project supports it. The text goes into the
document as it is. Give the `math` tag the attribute `display="block"` for a formula on
its own line.

A `diagram` shows an SVG file. The `src` option gives the path, as for an image, but the
render function puts the SVG into the document as an element and not as a data URI.
Therefore the rules of the theme reach the parts of the diagram. A `part` entity names an
element of the file by its `id`, and its `at` option and `on` entities give the steps.
The parts are the children of the diagram, so the transformer and the verifier treat them
as elements, and the render function writes the overlay attributes of each part on the
element of the file that has its `id`. A file without that `id` stops the render with a
message that names the id and the path. The `width` option gives the width of the
diagram as the option of an image does, through the custom property `--diagram-width`,
and a diagram without the option takes the width that the file gives.

The document holds one copy of the file for the present view and one for each page of the
handout view. A browser resolves a reference such as `url(#fill)` to the first element of
the document with that `id`, and a gradient in a hidden view does not paint. Therefore
the render function gives each copy its own ids: it puts a number after each `id`, and it
puts the same number into each `url(#id)` and each `href="#id"` of the copy. The number
comes from `System.unique_integer/1`, so two renders of one deck give different numbers.

The document passes Floki, and Floki writes each name of an SVG in lowercase, such as
`viewbox`. A browser reads the lowercase names inside an `svg` element as the names of
SVG, so the diagram keeps its meaning.

The theme makes `.text-area` a flex container. Each element inside a flex container is a
flex item, and a flex item also holds each run of text between two elements. Therefore
text with an inline element, such as `<b>`, breaks into more than one line. The render
function of a text area puts the text in one block element, which is one flex item. A
custom element that writes text from the deck must do the same.

## The DSL

`Expresso.Extension` gives the Spark extension. It contains one section, `deck`, which is a
top level section. The section holds `slide` entities. A `slide` holds `text_box` and
`pause` entities, and a `text_box` holds `text_area` and `on` entities. A `text_area`
holds `on` entities. A `slide` and a `text_box` also hold `image`, `list`, `table`,
`quotation`, `spacer`, `code`, `math`, `diagram` and `columns` entities. A `list` holds
`item` entities, a `table` holds `row` entities, a `diagram` holds `part` entities, and a
`columns` element holds `column` entities, which hold the elements of a text box.

Each element has an `at` option, a slide has a `steps` option and an `auto_reveal`
option, a list and a table have a `reveal` option, and a code element has a `reveal`
option with a list of lines. `docs/overlays.md` gives the meaning of each. A slide also
has a `heading` option, a `notes` option and a `handout` option, and
`Expresso.Slide.put_options_in_metadata/1` puts each into the metadata of the slide.

The `notes` option holds the notes of the speaker. The handout view shows them in an
`aside` element under each page of the slide, and the present view does not show them.
The text is not HTML, and a line break in the text gives a line break on the page.

The `print_notes` option of the deck leaves the notes out of the handout view and of the
print. The renderer writes `data-print-notes` on the `body` from the metadata of the
deck: `false` for `print_notes: false`, and `true` otherwise. The style sheet then hides
each `aside` in the handout view and on paper. The renderer still writes each `aside`,
because the speaker view reads the text of the notes from the page of the current step.

The `slide_numbers` option of the deck shows the number of each slide and the number of
slides, such as `3 / 12`. The renderer writes a `span` with the class `slide-number` into
the row of the footer, after the footer of the deck template, so the number shows with each
deck template. Slide 1 gets no number, because it is usually the title slide. The default
deck template gives an empty footer, so a deck does not show two numbers. In the present
view, the style sheet puts the number in the corner of the window, because a slide there is
only as wide as its content.

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
the current slide, the number of the current step, the view, the black screen and the
digits of a slide number. It also holds the function that changes them, and it does not
touch the document. `speaker.ts` makes the texts of the speaker view. `dom.ts` reads the
document. It applies a state with the inline `style.display` property, the `data-step`
attribute, and the `data-view` and `data-blank` attributes of the `body`. `main.ts`
connects the modules, and it writes the fragment of the address. The first slide is slide
1, and the first step is step 1. `docs/overlays.md` gives the rules of a step.

The unit tests of `assets/test/` test these modules with no browser. The browser tests of
`test/e2e/` open a rendered deck in Chromium and operate the presenter with its keys, with
the mouse and with a finger. `docs/development.md` gives both.

`Mix.Tasks.Compile.Presenter` bundles these modules with esbuild into one minified script,
`priv/static/presenter.js`. The compiler runs in front of the Elixir compiler, and Git does
not hold the bundle. The module is in `mix.exs`, because Mix runs the compilers before it
compiles `lib/`. `docs/typescript.md` gives the design.

The keys of the present view are:

- `j`, `ArrowRight`, `ArrowDown`, the space bar and `PageDown` show the next step, or the
  first step of the next slide after the last step.
- `k`, `ArrowLeft`, `ArrowUp` and `PageUp` show the previous step, or the last step of the
  previous slide at the first step.
- `Home` shows the first slide, and `End` shows step 1 of the last slide.
- A digit adds to a slide number, and `Enter` then shows step 1 of that slide. A number
  that is not a slide has no effect. Each other key removes the digits.
- `b` shows a black screen. The next key shows the slide again, and it does nothing more.
- `p` changes to the handout view.
- `s` opens the speaker view in a second window. A second `s` shows the same window.
- `f` puts the document in full screen, or takes it out of full screen.
- `o` shows the overview of the slides.
- `g` shows or hides the progress bar.
- `?` shows the list of the keys of the view. The next key closes it, and it does
  nothing more.

A click or a tap on the right two thirds of the window shows the next step, and on the left
third the previous step. A swipe of one finger to the left shows the next step, and to the
right the previous step. `side` and `swipe` in `state.ts` give these rules, and `point`
gives the state after them. As a key does, a click first closes a black screen or the list
of keys. The handout view scrolls with a finger, so there a click or a swipe does no more.

`main.ts` listens for `click`, `touchstart` and `touchend`. A swipe does not give a
`click`, so one movement does not move two steps. A click goes to the browser when it has
a modifier, when it is not the main button, when it ends a selection of text, or when it
is on a link, a button or a form field. `f` calls the full screen functions of the
browser, and `Escape` of the browser also takes the document out of full screen.

The table `BINDINGS` in `state.ts` gives each key, its function, the views that know it and
its text in the list of keys. `next` finds the function of a key in this table, and
`help.ts` makes the rows of the list from the same table. Therefore the list shows each key
that operates, and no other key. A row with no key gives the text of a click or a swipe in
the list, and `next` does not find it. `dom.ts` writes the rows into the element `help` as
text, and the style sheet shows it while the `body` has `data-help`. A printer does not get
the list.

The progress bar is the element `progress` at the bottom of the present view. The
renderer writes it into each document with a width of zero. It also writes `data-progress`
on the `body` from the metadata of the deck: `false` for `progress: false`, and `true`
otherwise. `main.ts` reads that attribute into the state at load, and `g` changes the
state. `fraction` in `state.ts` gives the part of the deck before the current step. Each
step of each slide counts one time, so the bar is full at the last step only. `dom.ts`
writes that part as the width of the bar. The style sheet shows the bar in the present view
only, and not on a black screen, in the overview or on paper. A theme can set
`--progress-color` and `--progress-height`.

The `transition` option of the deck gives the transition from one slide to the next in the
present view: `:fade`, `:slide`, `:zoom` or `:none`. The default is `:fade`. A slide can
have the same option, and `Expresso.Slide.put_options_in_metadata/1` puts it into the
metadata of the slide. The renderer writes the kind of each slide as `data-transition` on
its `section` of the present view. The slide option comes first, then the deck option, then
`fade`.

`transition` in `state.ts` decides if a change of state has a transition. Only a move to a
different slide in the present view has one. A change of the step, a black screen, the
overview and the list of keys have none. A transition belongs to the border between two
slides, so the slide with the higher number gives the kind in the two directions. A move
forward uses the kind of the next slide. A move back uses the kind of the slide that it
leaves, and the direction `back` plays it in reverse.

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

The overview shows the page of the last step of each slide in a grid. The state holds
`overview` and `selected`, the number of the selected slide. `o` opens the overview, and it
selects the current slide. While the overview shows, `mode` in `state.ts` gives
`"overview"`. `binding` then finds only the keys of the rows for that mode, and the list of
keys of the overview shows only these keys.

`j`, `k`, the arrow keys, `Home` and `End` select a different slide. A key that selects a
slide outside the deck has no effect. `Enter` and a click on a slide call `choose`, which
closes the overview and goes to step 1 of the slide. `o` and `Escape` close the overview,
and the step does not change.

`columns` in `state.ts` gives the number of columns: the square root of the number of
slides, or the next larger integer. The number of rows is then not more than the number of
columns. `dom.ts` writes `data-thumbnail` on the page of the last step of each slide, and
`data-selected` on the page of the selected slide. It also writes `--overview-columns` and
`--overview-zoom` on the `body`, and the style sheet scales each page with `zoom`. The
padding and the gaps of the grid are 1vw wide and 1vh high, so the grid of each deck fits in
the window.

In the speaker view, the overview replaces the grid of the speaker view while it shows. A
theme can set `--overview-color` for the outline of the selected slide.

The handout view knows only `j`, `k`, `p`, `a` and `?`. `j` and `k` change the state, and
`p` then shows that step in the present view. The browser keeps each other key, so the arrow
keys and the space bar scroll the pages. A key with the Control, Alt or Meta modifier always
goes to the browser. `main.ts` stops the default operation of a key only when the key
changes the state.

The speaker view is the same document in a second window, with `?speaker` in the address.
It shows two pages of the handout view: the page of the current step and the page of the
next step. `dom.ts` writes `data-speaker` on these two pages, and the style sheet puts them
in a grid and scales them with `zoom`. The notes of the current page, the position and a
timer go into three elements that `dom.ts` makes. The speaker view knows the keys of the
present view, but `p` and `s` have no function in it. `r` sets the timer back to `0:00`,
and the timer then starts at the next change of the step.

The `duration` option of the deck gives the length of the talk in minutes. The renderer
writes it as `data-duration` on the `body`, and `?duration=` in the address replaces it.
`talkLength` in `speaker.ts` reads the two values. `dom.ts` makes a fourth element of the
speaker view, `speaker-left`, and the speaker view writes the time left into it. `pace`
gives its value of `data-pace`: `on`, `behind` or `over`. For a talk with no length, the
element has no text, and the style sheet hides it.

The pace compares the time used with `done` in `state.ts`: the part of the steps before the
current step. The speaker is `behind` when the time used is more than one minute longer than
that part of the time. `done` is not `fraction`, because `fraction` is 1 at the last step,
and the last step also needs its part of the time. The time left goes up to the next full
second, so the timer and the time left always give the length of the talk.

Each window sends its position to the other window with `postMessage`. The message holds
the slide, the step and the black screen, so `b` in the speaker view gives a black screen
to the audience. A window accepts a message only from the other window. The present view
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
changes of both, also after a reload. Before this rule, each window sent each position back.
Two keys that came faster than a message then gave a loop: the echo of the first key came
back after the second key, and the two windows sent the two positions to each other with no
end.

The fragment of the address holds the slide and the step, such as `#4.2`. `main.ts` reads
it at load and at each `hashchange` event. It writes the fragment with
`history.replaceState` after each change, so the history of the browser gets no entry for
a step. A fragment that gives no slide and step of the deck has no effect. `#4` is step 1
of slide 4.
A printer gets the handout view, because a `@media print` block selects it. The key is
not necessary for a printer. It makes the handout view available on a screen, and a
screen reader then reads each page of it.

The `handout` option of a slide selects the steps that get a page in the handout view and
on paper, such as `handout [2, :last]`. The `handout` option of the deck gives `:all` or
`:last` to each slide without the option, and its default is `:all`. `Expresso.Handout`
gives the forms and the steps. The renderer still writes a page for each step, because
the speaker view shows the page of each step. It writes `data-omit` on each page that the
option does not select. The style sheet hides such a page in the handout view and on
paper, so the handout view on a screen shows the pages that a printer prints.

The key `a` of the handout view changes the `every` field of the state, and `dom.ts`
writes it into `data-every` on the `body`. With `data-every="true"`, the style sheet shows
each page in the handout view and on paper. A print then gets every step, whatever the
`handout` options select. The field stays in one window, and a print from the speaker
view gets the selection.

`?all` in the address gives the field the value `true` at load. A print with no key, such
as the `--print-to-pdf` option of Chromium with no window, then gets every step. The key
`a` can still change the field. The speaker view opens with the address of the present
view, so it keeps `?all`.

Each page that shows, except the first, starts a new sheet with `break-before`. With
`data-every="true"`, each page except the first does. A rule of
`break-after` on the last page cannot do this, because the last page of the document can
be a page with `data-omit`. The print block also hides the four elements of the speaker
view, so a print from that window gives the same pages.

A page of the handout view takes the full height of the screen, or of the paper. The
print block gives the paper a landscape orientation, because a slide is wider than it is
high. Therefore each page keeps the proportions of a slide.

## The build

The repository gives a Nix shell. `flake.nix` and `shell.nix` give Erlang/OTP 29, Elixir
1.20, Node 24 and Zig 0.16. Zig is a dependency of Burrito. `package.json` gives Prettier
and the other tools of the presenter script. The `.tool-versions`
file gives the same versions for a different tool manager, and
`.claude/hooks/session-start.sh` gives them to a remote session.

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
it. `.github/workflows/check.yml` runs each check for a pull request in parallel jobs, on
the versions of `.tool-versions`.

One question has no answer, and the maintainer decides it. The section "The imperative
API" of `docs/overlays.md` asks whether `Expresso.Deck.add_slide/4` keeps parity with the
DSL for an overlay, or whether an overlay needs the DSL.
