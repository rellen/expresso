# The code element

The `code` element shows source code with the colors of its language. The source is the
`text` option, or the file of the `src` option.

```elixir
slide "the server" do
  code "elixir" do
    src "lib/my_app/server.ex"
    lines 40..58
    line_numbers true
    reveal [40..44, 45..52, 53..58]
    dim true
  end
end
```

`Expresso.Builder` takes the same options, such as
`code("elixir", src: "lib/my_app/server.ex", lines: 40..58, line_numbers: true)`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | The name of a language, such as `"elixir"` or `"js"` | The colors of the language. See [the languages](#the-languages). Without it, the code has no colors. |
| `text` | A string | The source code. |
| `src` | The path of a file, relative to the working directory of the command | The source code is the text of the file. |
| `lines` | A range, such as `10..24` | The element shows only these lines of the `src` file. The default is each line. |
| `line_numbers` | `true` or `false` | Show the number of each line. The default is `false`. |
| `reveal` | Line numbers and ranges, such as `[10..12, 13..20]` | Each group of lines shows at its own step. See [the overlay options](overlay-options.md). |
| `dim` | `true` or `false` | Each group dims when a later group shows. |
| `highlight` | Line numbers and ranges, such as `[10..12, 13..20]` | Each line shows at each step. Each group is in focus at its own step, and the other lines dim. |
| `class` | CSS class names | See [the class option](class-option.md). |

The element takes `text` or `src`, and not both. It takes `reveal` or `highlight`, and not
both.

## The languages

A lexer gives the colors of a language. These names have a lexer:

`c`, `css`, `diff`, `eex`, `elixir`, `erl`, `erlang`, `gleam`, `heex`, `html`, `html.eex`, `html_eex`, `iex`, `javascript`, `js`, `json`, `rust`, `sql`, `ts`, `typescript`

`Expresso.Highlight.languages/0` returns the same list. A code element with another name
shows its lines with no colors, as an element with no language does.

## Code from a file

The element reads the file of `src` when the deck compiles, and `Expresso.Builder.code/2`
reads it when it makes the element. The text of the lines of `lines` is then the source of
the element.

- `mix expresso` reads the file each time that it renders the deck.
- The watch mode renders the deck again after a change to the file.

For the steps, see [Show code on a slide](../how-to/show-code.md).

## The errors

The compiler gives an error for:

- an element with both `text` and `src`, or with neither,
- a `lines` option without `src`,
- a file that it cannot read,
- a `lines` range that goes past the end of the file,
- a number of `reveal` or `highlight` that the element does not show,
- `reveal` and `highlight` together, and `highlight` with `dim`,
- a line that is in two groups of `highlight`.

`Expresso.Builder.code/2` raises an `ArgumentError` with the same message.

## The warnings

The compiler gives a warning for a language that no lexer registers, such as `"elixr"`.
The warning names the slide and gives the list of the languages. The deck still compiles,
and the element shows its lines with no colors. `Expresso.Builder.deck/2` writes the same
warning to the standard error.

## The numbers of the lines

Each line has a number. The first line of the `text` option is line 1. With `src`, the
number of a line is its number in the file, so the first line of `lines 40..58` is line 40.

The `reveal` option uses the same numbers. A group of lines in the deck therefore has the
numbers that the slide shows.

With `line_numbers true`, each line starts with its number. The numbers stand in one
column, with the color of the comments of the theme. A screen reader does not read the
numbers, and a copy of the text from the slide does not take them.

## The highlight option

The `highlight` option takes groups of lines, in the same form as `reveal`. Each line
shows at each step. Each group is in focus at one step, in the order of the option:

| Step | The lines of the group | Each other line |
| --- | --- | --- |
| The step of the group | Full opacity, and a bar in the color `--accent` at the left | Each color of the line changes to its dimmed color |
| A step of no group | Full opacity | Full opacity |

The groups take their steps from the counter of the slide, one step each, as the items of
a list with `reveal true` do. The first group is thus in focus at the first step of the
slide. A `pause()` in front of the code element gives one step with no line in focus. See
[the overlay options](overlay-options.md).

A line can be in one group only. A line in no group dims at each step of a group.

The bar is a shadow at the left of the line. It takes no space, so the text does not move.
