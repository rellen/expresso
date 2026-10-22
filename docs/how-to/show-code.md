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
2. Give the text in `lines`, with `to: :block`. The excerpt then ends at the end of the
   block of the first line, such as its `end` or its `}`:

   ```elixir
   code "elixir" do
     src "lib/my_app/server.ex"
     lines from: "def handle_call(", to: :block
   end
   ```

To end the excerpt at another line, give a text of that line in `to`, such as
`to: "{:reply"`. The excerpt then ends at the first copy of the text after the first line.
The groups of `reveal` and `highlight` take `to: :block` too.

The compiler gives an error when a text is not in the file, and when the `from` text is in
it more than one time. Give a longer text, such as `"def handle_call(:next"`, to make it
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

## Keep the groups on their lines

A number of `reveal` or `highlight` is the number of a line in the file. A change above the
excerpt moves the lines, and each group then shows other lines with no error. Give each
group by its text, in the form of `lines`. The group runs from the line of `from` to the
line of `to`, inside the excerpt. A group with only `from` is one line:

```elixir
defmodule Examples.CodeTextGroups do
  use Expresso

  root __DIR__

  slide "the counter" do
    heading "The counter"

    code "elixir" do
      src "counter.ex"
      lines from: "def handle_call(", to: :block
      line_numbers true
      highlight [[from: "def handle_call("], [from: "next = ", to: "{:reply"]]
    end
  end
end

Examples.CodeTextGroups
```

![The first line of the function is in focus, then the two lines that count and reply](https://raw.githubusercontent.com/rellen/expresso/media/code-text-groups.gif)

Each text must be in the excerpt one time, or the compiler gives an error. A group can mix
with numbers, such as `[1, [from: "next = "]]`.

To keep the numbers, but count them from the excerpt, give `relative true`. Then `1` is the
first line of the excerpt, whatever its number in the file:

```elixir
code "elixir" do
  src "lib/my_app/server.ex"
  lines from: "def handle_call(", to: :block
  relative true
  highlight [1, 2..3]
end
```

A line added inside the excerpt still moves the numbers. Texts move with the code.

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
      lines from: "def handle_call(", to: :block
      line_numbers true
      highlight [13, 14]
      whole_first true
    end
  end
end

Examples.CodeWholeFirst
```

![The whole function shows at step 1, then line 13 and line 14 come into focus](https://raw.githubusercontent.com/rellen/expresso/media/code-whole-first.gif)

## Show each line during a question

A question from the audience can be about a line that dims. Press `d` in the present view
or in the speaker view. Each line of code then shows in full color, and the step does not
change:

1. Press `d`. The dimmed lines of code show in full color.
2. Answer the question.
3. Press `j` to go on. The next step dims the lines again, so you do not press `d` again.

`d` changes code only, so a list with `dim true` stays dimmed. The bar of `highlight` stays
on the group in focus, and the handout view keeps the dimming of each step.

In this deck, line 14 dims at the first step. The recording presses `d`, then `j`:

```elixir
defmodule Examples.CodeUndim do
  use Expresso

  slide "the counter" do
    heading "The counter"

    code "elixir" do
      src "examples/animations/counter.ex"
      lines from: "def handle_call(", to: :block
      line_numbers true
      highlight [13, 14]
    end
  end
end

Examples.CodeUndim
```

![The dimmed lines show in full color after d, and the next step dims them again](https://raw.githubusercontent.com/rellen/expresso/media/code-undim.gif)

## Show a configuration file

Give the name of the language of the file, such as `"toml"`, `"yaml"` or `"nix"`. Expresso
has lexers for many such languages, as well as the languages of programs. For each name, see
[the languages](../reference/code-element.md#the-languages).

A document in Org, reStructuredText, LaTeX or Typst works in the same way. Its lexer colors
the headings, the markup, the commands and the comments.

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

## Put the code into a window

Give the deck the `window` option, and each code element goes into a frame that looks like a
window of macOS. The bar shows the name of the file of `src`. A code element can give its
own `window` style and its own `window_title`. `:terminal` suits the output of a command:

```elixir
defmodule Examples.CodeWindow do
  use Expresso

  root __DIR__
  window(:macos)

  slide "the counter" do
    heading "The counter"

    code "elixir" do
      src "counter.ex"
      lines 8..15
      highlight [[from: "def init"], [from: "def handle_call", to: :block]]
    end
  end

  slide "the tests" do
    heading "The tests"

    code do
      window(:terminal)
      window_title("~/counter — zsh")

      text """
      $ mix test
      ...
      Finished in 0.02 seconds (0.00s async, 0.02s sync)
      3 tests, 0 failures
      """
    end
  end
end

Examples.CodeWindow
```

![Lines of a file in a window with three colored dots and the name of the file, with one function and then the next in focus, then the output of mix test in a terminal window](https://raw.githubusercontent.com/rellen/expresso/media/code-window.gif)

The two windows are code elements on neighbor slides, so the window moves from one slide to
the next. An image and an embed take the same options. See
[the window option](../reference/window-option.md).

## Make sure that the lines fit

A long line breaks on the slide, and the reader then sees two lines with one number. Open
the document with `?check` at the end of the address, and the report gives each code
element with a line that breaks. See [Check that a deck fits the screen](check-the-layout.md).

## Show the long lines of real code

The lines of a real file are often longer than a slide, and many end with a comment. Give
`trailing_comments false` to remove a comment at the end of a line of code. A line that is
only a comment stays. Give `wrap true` to break each line that is still too long, with its
next parts indented under its start:

```elixir
defmodule Examples.CodeLongLines do
  use Expresso

  slide "the reservation" do
    heading "Book the floor"

    code "js" do
      text """
      // anyone else's booking that meets b: the one that ends last
      function resHit(m, b) {
        let hit = null;               // (the latest booking that meets b)
        for (const [who, r] of RES) {
          if (who === m || r.t1 <= b.t0 || b.t1 <= r.t0 || !boxesMeet(r, b)) continue;
          for (const q of r.list) if (q.t0 < b.t1 && b.t0 < q.t1 && boxesMeet(q, b) && (!hit || q.t1 > hit.t1)) hit = { who, q };
        }
        return hit;                   // (null when the floor is free)
      }
      """

      trailing_comments false
      wrap true
    end
  end
end

Examples.CodeLongLines
```

![A function with no comments at the ends of its lines, and a long line that breaks with its second part indented](https://raw.githubusercontent.com/rellen/expresso/media/code-long-lines.png)

`?check` does not report a line of a code element with `wrap`, because the line breaks on
purpose. Give a smaller font with [the class option](../reference/class-option.md) when
the lines must not break.
