# Show code on a slide

This guide shows how to put source code on a slide: from the deck, or from a file of your
project, with the numbers of its lines and with groups of lines that show one after the
other. For each option, see [The code element](../reference/code-element.md).

## Show a short example

Write the code in the `text` option, and give the language as the first argument:

```elixir
slide "hello" do
  code "elixir" do
    text ~S"""
    def hello(name), do: "Hello, #{name}!"
    """
  end
end
```

Use the sigil `~S`, so `#{name}` stays text and Elixir does not run it.

The compiler gives a warning for a language that no lexer registers, such as `"elixr"`,
and the code then shows with no colors. The warning lists the languages that have a lexer.
For the list, see [the languages](../reference/code-element.md#the-languages).

## Show lines of a file

Use a file for code that your project holds. The slide then shows the code as it is in the
file, and a change to the file changes the slide.

1. Find the numbers of the first line and of the last line in your editor, such as 40 and
   58.
2. Give the path of the file in `src`, and the numbers in `lines`:

   ```elixir
   slide "the server" do
     code "elixir" do
       src "lib/my_app/server.ex"
       lines 40..58
     end
   end
   ```

3. Render the deck from the directory of the project, because the path is relative to the
   working directory of the command. With the `root` option, the path starts from the
   directory of the option. See
   [Show code from the project of the deck](#show-code-from-the-project-of-the-deck).

Without `lines`, the slide shows each line of the file.

In the watch mode, a change to the file renders the deck again. With a range of line
numbers, a change above the lines moves them, so the slide then shows different lines. To
keep the same lines, find them by their text.

## Find the lines by their text

1. Find a text that starts the first line, such as `def handle_call(`. The text must be in
   the file one time only.
2. Find a text that ends the excerpt, such as `"\n  end"`. The excerpt ends at the first
   copy of this text after the first line.
3. Give the two texts in `lines`:

   ```elixir
   code "elixir" do
     src "lib/my_app/server.ex"
     lines from: "def handle_call(", to: "\n  end"
   end
   ```

The compiler gives an error when a text is not in the file, and when the `from` text is in
it more than one time. Give a longer text, such as `"def handle_call(:get"`, to make it
one time. A change above the excerpt then does not move it. The example in
[Show the whole code first](#show-the-whole-code-first) uses this option.

## Show code from the project of the deck

A relative path starts from the working directory of the command. Give the deck the `root`
option, and each path then starts from your project, so the deck renders from any
directory:

```elixir
defmodule MyTalk.Deck do
  use Expresso

  root Path.expand("..", __DIR__)

  slide "the server" do
    code "elixir" do
      src "lib/my_app/server.ex"
      lines 40..58
    end
  end
end
```

In the deck file, `__DIR__` is the directory of the file, so `Path.expand("..", __DIR__)`
is the project of a deck in `talk/`. For the steps, and for `mix expresso` in your
project, see [Render a deck in your project](render-a-deck-in-your-project.md).

## Show the numbers of the lines

Write `line_numbers true`. With `src`, the numbers are the numbers of the file, so they
agree with your editor:

```elixir
code "elixir" do
  src "lib/my_app/server.ex"
  lines 40..58
  line_numbers true
end
```

## Show the lines in groups

Write `reveal` with a range for each group. Each group shows at its own step. With `src`,
give the numbers of the file. Add `dim true` to dim each group when the next group shows:

```elixir
code "elixir" do
  src "lib/my_app/server.ex"
  lines 40..58
  line_numbers true
  reveal [40..44, 45..52, 53..58]
  dim true
end
```

For the steps of a slide, see [Animate elements in a slide](animate-elements.md).

## Point at lines one group at a time

Write `highlight` with a range for each group. Each line shows at each step. At the step
of a group, its lines show in full with a bar at the left, and the other lines dim:

```elixir
code "elixir" do
  src "lib/my_app/server.ex"
  lines 40..58
  line_numbers true
  highlight [40..44, 45..52, 53..58]
end
```

Use `reveal` to show new lines at each step, and `highlight` to point at lines that the
audience already sees. A code element takes one of the two options.

## Show the whole code first

The first group of `highlight` is in focus at the first step of the code. To show the
whole code in full color first, write `whole_first true`. The code then takes one step
with no group in focus, as a `pause()` in front of it does.

This deck shows the function `handle_call/3` of the file
`examples/animations/counter.ex`. It finds the lines by their text, and it puts line 13,
then line 14, in focus:

```elixir
defmodule Examples.CodeWholeFirst do
  use Expresso

  slide "the counter" do
    heading "The counter"

    code "elixir" do
      src "examples/animations/counter.ex"
      lines from: "def handle_call(", to: "\n  end"
      line_numbers true
      highlight [13, 14]
      whole_first true
    end
  end
end

Examples.CodeWholeFirst
```

![The whole function shows at step 1, then line 13 and line 14 come into focus](https://raw.githubusercontent.com/rellen/expresso/media/code-whole-first.gif)

## Show a configuration file

Give the name of the language of the file, such as `"toml"`, `"yaml"` or `"nix"`. Expresso
has lexers for `cabal`, `d2`, `dhall`, `kdl`, `nix`, `toml` and `yaml`, as well as the
languages of programs. For each name, see [the languages](../reference/code-element.md#the-languages).

This deck shows a TOML file, and it puts the table of the server, then the table of the
database, in focus:

```elixir
defmodule Examples.CodeConfig do
  use Expresso

  slide "the configuration" do
    heading "The configuration"

    code "toml" do
      text ~S"""
      # The server
      [server]
      host = "localhost"
      port = 8080

      [database]
      url = "postgres://localhost/app"
      pool = 10
      """

      line_numbers true
      highlight [2..4, 6..8]
    end
  end
end

Examples.CodeConfig
```

![The table of the server is in focus, then the table of the database](https://raw.githubusercontent.com/rellen/expresso/media/code-config.gif)

## Make sure that the lines fit

A long line breaks on the slide, and the reader then sees two lines with one number. Open
the document with `?check` at the end of the address, and the report gives each code
element with a line that breaks. See [Check that a deck fits the screen](check-the-layout.md).
