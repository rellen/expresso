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
| `src` | The path of a file, relative to [the root option](root-option.md) of the deck, or to the working directory of the command | The source code is the text of the file. |
| `lines` | A range, such as `10..24`, or texts, such as `[from: "def start(", to: :block]` | The element shows only these lines of the `src` file. See [lines from a text](#lines-from-a-text). The default is each line. |
| `line_numbers` | `true` or `false` | Show the number of each line. The default is `false`. |
| `reveal` | Line numbers, ranges and texts, such as `[10..12, 13..20]` or `[[from: "def start(", to: "end"]]` | Each group of lines shows at its own step. See [the groups](#the-groups) and [the overlay options](overlay-options.md). |
| `dim` | `true` or `false` | Each group dims when a later group shows. |
| `highlight` | Groups in the form of `reveal` | Each line shows at each step. Each group is in focus at its own step, and the other lines dim. |
| `trailing_comments` | `true` or `false` | `false` removes a comment at the end of a line of code. See [long lines](#long-lines). The default is `true`. |
| `wrap` | `true` or `false` | Break a long line with its next parts indented. See [long lines](#long-lines). The default is `false`. |
| `relative` | `true` or `false` | Count the numbers of `reveal` and `highlight` from the first line of the excerpt. The default is `false`. |
| `whole_first` | `true` or `false` | With `highlight`, the whole code shows in full color for one step before the first group. The default is `false`. |
| `window` | `:macos`, `:terminal`, `:plain` or `:none` | A frame that looks like a window. The default is the `window` option of the deck. See [the window option](window-option.md). |
| `window_title` | A string | The text of the bar of the window. Without it, a code element with `src` shows the name of its file. |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

The element takes `text` or `src`, and not both. It takes `reveal` or `highlight`, and not
both.

## The languages

A lexer gives the colors of a language. These names have a lexer:

`c`, `cabal`, `css`, `d2`, `dhall`, `diff`, `eex`, `elisp`, `elixir`, `emacs-lisp`, `erl`, `erlang`, `fennel`, `fnl`, `gleam`, `haskell`, `heex`, `hs`, `html`, `html.eex`, `html_eex`, `iex`, `javascript`, `js`, `json`, `kdl`, `latex`, `nix`, `org`, `orgmode`, `restructuredtext`, `rst`, `rust`, `sql`, `tex`, `toml`, `ts`, `typ`, `typescript`, `typst`, `yaml`, `yml`

A Makeup package of Hex gives the lexer of most of these languages. Expresso gives its own
lexer for these languages:

| Language | Names | The parts with a color |
| --- | --- | --- |
| Cabal | `cabal` | fields, sections, versions, conditions, comments |
| D2 | `d2` | reserved keys such as `shape`, keys, connections, strings, block strings, comments |
| Dhall | `dhall` | keywords, built-in types and functions, fields, imports, strings, comments |
| Emacs Lisp | `elisp`, `emacs-lisp` | special forms, the name of a definition, built-ins, keywords such as `:key`, characters, quotations, comments |
| Fennel | `fennel`, `fnl` | special forms, the name of a definition, built-ins of Lua, keywords such as `:key`, `$1`, comments |
| Haskell | `haskell`, `hs` | keywords, the name at the start of a line, types and constructors, pragmas, functions in backticks, characters, comments |
| KDL | `kdl` | node names, properties, type annotations, `#true` and the other constants, `/-`, strings, comments |
| LaTeX | `latex`, `tex` | commands, the commands of the structure, environments, math, escapes, comments |
| Nix | `nix` | keywords, attributes, paths, built-ins, strings, comments |
| Org | `org`, `orgmode` | headings with their state, keyword lines, drawers, lists, `*bold*` and the other markup, links, dates, comments |
| reStructuredText | `rst`, `restructuredtext` | section titles, directives, fields, lists, `**strong**` and the other markup, roles, links, comments |
| TOML | `toml` | table headers in the first column, keys, dates, strings, constants, comments |
| Typst | `typst`, `typ` | headings, `*strong*` and the other markup, keywords and functions after `#`, labels, references, math, numbers with a unit, URLs, comments |
| YAML | `yaml`, `yml` | keys, document markers, anchors, aliases, tags, constants, strings, block scalars as plain text, comments at the start of a line or after white space |

Such a lexer finds the parts that a slide colors, and not each rule of the language.

`Expresso.Highlight.languages/0` returns the same list. A code element with another name
shows its lines with no colors, as an element with no language does.

## Code from a file

The element reads the file of `src` when the deck compiles, after the deck gives its
`root` option. `Expresso.Builder.deck/2` reads it in the same way, so the element of
`Expresso.Builder.code/2` holds no text until it is in a deck. The text of the lines of
`lines` is then the source of the element.

- `mix expresso` reads the file each time that it renders the deck.
- The watch mode renders the deck again after a change to the file.
- The file must be UTF-8. The compiler gives an error that names a file with a different
  encoding, such as Latin-1.

### Lines from a text

A range of line numbers moves when a change adds or removes lines above it. The slide then
shows other lines, and it gives no error. A `lines` option with texts finds the excerpt
from the text of the file:

| Key | Value | Effect |
| --- | --- | --- |
| `from` | The text of the first line, or a part of it | The excerpt starts at the line that holds the text. The default is line 1. |
| `to` | The text of the last line, or a part of it, or `:block` | The excerpt ends at the line that holds the last character of the text. The text is the first one after the start of the `from` text. With `:block`, the excerpt ends at [the end of the block](#the-end-of-a-block) of the `from` line. The default is the last line. |

A text can hold a line break, such as `"\n  end"`, which is the first line of the file
that starts with `  end`. The lines keep their numbers in the file, so the first line of
the excerpt can be line 40. A `reveal` or a `highlight` uses those numbers.

For the steps, see [Show code on a slide](../how-to/show-code.md).

### The end of a block

`to: :block` ends the lines at the end of the block that the `from` line opens, such as a
function, an `if` or a `do` block. The indent finds the block, so a change of the indent of
the file does not break the option:

1. The block holds each later line with more indent than the `from` line, and the blank
   lines between them.
2. The first later line with the same indent or less ends the block.
3. That line is the last line of the block when it starts with `}`, `]`, `)` or `end`.
   Otherwise the last line of the block is the last line with more indent, as in Python.

A `from` line with no line of more indent after it is a block of one line. Its group does
not take the closing line of a block around it.

```elixir
code "js" do
  src "assets/line4.html"
  lines from: "function resHit(m, b, m2) {", to: :block
  highlight [[from: "if (extra) {", to: :block], [from: "return hit;"]]
end
```

## The errors

The compiler gives an error for:

- an element with both `text` and `src`, or with neither,
- a `lines` option without `src`,
- a file that it cannot read, or that is not UTF-8,
- a `lines` range that goes past the end of the file,
- a `from` text that is not in the file, or that is in it more than one time,
- a `to` text that is not in the file after the `from` text,
- a `whole_first` option without `highlight`,
- a number of `reveal` or `highlight` that the element does not show,
- a group with a `from` text that is not in the code, or that is in it more than one time,
- a group with a `to` text that is not in the code after its `from` text, and a group with
  a `to` text and no `from` text,
- `reveal` and `highlight` together, and `highlight` with `dim`,
- a line that is in two groups of `highlight`,
- a token group in `reveal`.

The render gives an error for a token group with no token.

`Expresso.Builder.code/2` raises an `ArgumentError` with the same message for an option.
`Expresso.Builder.deck/2` raises a `Spark.Error.DslError` for an error of the file, such as a
file that it cannot read.

## The warnings

The compiler gives a warning for a language that no lexer registers, such as `"elixr"`.
The warning names the slide and gives the list of the languages. The deck still compiles,
and the element shows its lines with no colors. `Expresso.Builder.deck/2` writes the same
warning to the standard error.

## The groups

A group of `reveal` or `highlight` takes one of these forms:

| Form | Example | Lines |
| --- | --- | --- |
| A number | `12` | The line with that number. |
| A range | `12..15` | The lines with those numbers. |
| Texts | `[from: "next = ", to: "{:reply"]` | From the line that holds the `from` text to the line that holds the last character of the `to` text. |
| A block | `[from: "if (extra) {", to: :block]` | From the line that holds the `from` text to [the end of its block](#the-end-of-a-block). |
| A start text only | `[from: "def handle_call("]` | The line that holds the text. |
| Each token with a text | `[each: "count"]` | No line. Each token with the text is in focus. Only `highlight` takes this form. See [each token with a text](#each-token-with-a-text). |

A number is the number of the line in the file, as [the numbers of the lines](#the-numbers-of-the-lines)
tell. With `relative true`, a number counts from the first line of the excerpt, so `1` is
that line. Texts are found inside the text of the element, with the rules of
[lines from a text](#lines-from-a-text): the `from` text must be in it one time, and the
`to` text must come after it. The forms can mix in one option.

## Long lines

A line that is too long for the element breaks at the edge. Two options help:

| Option | Effect |
| --- | --- |
| `trailing_comments false` | The lexer of the language finds each comment. A comment at the end of a line that has code before it goes, with the white space before it. A line that is only a comment stays. A code element with no lexer keeps each comment. |
| `wrap true` | The element gets the class `code-wrap`, and each line gets `--indent`, the width of its white space at the start. A tab counts as 8 characters. The next parts of a broken line start 4 characters further in than the text of the line. `?check` does not report the lines of the element. |

The two options change only the slide. `lines`, the groups of `reveal` and `highlight`,
and the texts of `from` and `to` still read the text of the file.

## The numbers of the lines

Each line has a number. The first line of the `text` option is line 1. With `src`, the
number of a line is its number in the file, so the first line of `lines 40..58` is line 40.

The `reveal` option uses the same numbers. A group of lines in the deck therefore has the
numbers that the slide shows.

With `line_numbers true`, each line starts with its number. The numbers stand in one
column, with the color of the comments of the theme. A screen reader does not read the
numbers, and a copy of the text from the slide does not take them.

## The place on the slide

A code element that is alone in its parent takes the free height, and its code stays in the
center. Code elements that share a parent, such as two excerpts in one column, take only
the height of their lines. Their code starts at the left edge of the parent, so the lines
of each excerpt align.

## The highlight option

The `highlight` option takes groups of lines, in the same form as `reveal`. Each line
shows at each step. Each group is in focus at one step, in the order of the option:

| Step | The lines of the group | Each other line |
| --- | --- | --- |
| The step of the group | Full opacity, and a bar in the color `--accent` at the left | Each color of the line changes to its dimmed color |
| A step of no group | Full opacity | Full opacity |

The groups take their steps from the counter of the slide, one step each, as the items of
a list with `reveal true` do. The first group is thus in focus at the first step of the
slide. `whole_first true` gives the code element one step with no line in focus before the
first group, as a `pause()` in front of the code element does. See
[the overlay options](overlay-options.md).

A line can be in one group only. A line in no group dims at each step of a group.

The bar is a shadow at the left of the line. It takes no space, so the text does not move.

### Each token with a text

A group `[each: "count"]` puts each token with the text `count` in focus, such as each use
of a variable. At the step of the group, each line dims, and each token with the text shows
in full color with a bar in the color `--accent` under it.

```elixir
code "elixir" do
  src "lib/counter.ex"
  highlight [[each: "count"], 12..14]
end
```

- A token is a word, a number or a sign that the lexer of the language finds. The text
  must be the whole token, so `[each: "count"]` does not select `counter` or `@count`.
- A token in focus keeps the color of its role, such as the color of a keyword.
- The bar goes under the word. A token at the start of a line keeps its indent, so its bar
  also goes under the indent.
- At the step of a line group, a token dims with its line.
- A code element without a lexer has no token, so it gives an error for a token group.
- `reveal` does not take a token group, because a hidden token leaves a hole in its line.

### The key d

The key `d` turns off the dimming of each code element and of each series of a chart in
the present view, until the next change of the step. It works in the present view and in
the speaker view, and the two windows show the same result.

- The lines that dim show in full color. The bar stays on the group in focus.
- A line that `reveal` hides stays hidden.
- A series of a chart that `highlight` or `dim true` dims shows in full color. See
  [a dimmed series](chart-element.md#a-dimmed-series).
- Each other element, such as a list with `dim true`, keeps its dimming.
- The handout view and paper keep the dimming of each step.

For the steps, see
[Show each line during a question](../how-to/show-code.md#show-each-line-during-a-question).
