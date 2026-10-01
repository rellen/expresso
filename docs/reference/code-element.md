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
| The first argument | The name of a language, such as `"elixir"` or `"js"` | The colors of the language. `Expresso.Highlight` names the languages. Without it, the code has no colors. |
| `text` | A string | The source code. |
| `src` | The path of a file, relative to the working directory of the command | The source code is the text of the file. |
| `lines` | A range, such as `10..24` | The element shows only these lines of the `src` file. The default is each line. |
| `line_numbers` | `true` or `false` | Show the number of each line. The default is `false`. |
| `reveal` | Line numbers and ranges, such as `[10..12, 13..20]` | Each group of lines shows at its own step. See [the overlay options](overlay-options.md). |
| `dim` | `true` or `false` | Each group dims when a later group shows. |

The element takes `text` or `src`, and not both.

## Code from a file

Use `src` for code that is in a file of your project. The slide then shows the code as it
is in the file, and a change to the file changes the slide. A copy in the `text` option can
become different from the file with no error.

- `mix expresso` reads the file each time that it renders the deck.
- The watch mode renders the deck again after a change to the file.
- The compiler gives an error for a file that it cannot read, and for a `lines` range that
  goes past the end of the file.

## The numbers of the lines

Each line has a number. The first line of the `text` option is line 1. With `src`, the
number of a line is its number in the file, so the first line of `lines 40..58` is line 40.

The `reveal` option uses the same numbers. Thus a group of lines in the deck agrees with
the numbers on the slide and with the numbers in your editor. The compiler gives an error
for a number of `reveal` that the element does not show.

With `line_numbers true`, each line starts with its number. The numbers stand in one
column, with the color of the comments of the theme. A screen reader does not read the
numbers, and a copy of the text from the slide does not take them.
