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
   working directory of the command.

Without `lines`, the slide shows each line of the file.

In the watch mode, a change to the file renders the deck again. A change above the lines
moves them, so the slide then shows different lines. Look at the slide after a change to
the file.

## Show code from the project of the deck

A relative path is relative to the working directory of the command, and not to the deck
file. Give each path from the directory of the deck instead, so that the deck renders from
any directory:

1. Put the deck file in your project, such as `talk/deck.exs`.
2. Add a module attribute with the root of the project, from `__DIR__`. In the deck file,
   `__DIR__` is the directory of the file.
3. Join each path to the root:

   ```elixir
   defmodule MyTalk.Deck do
     use Expresso

     @root Path.expand("..", __DIR__)

     slide "the server" do
       code "elixir" do
         src Path.join(@root, "lib/my_app/server.ex")
         lines 40..58
       end
     end
   end
   ```

4. Render the deck with the binary of Expresso, from any directory:

   ```sh
   expresso_cli_app_linux_x86 talk/deck.exs talk/deck.html
   ```

Each option of the DSL is an expression, so the same pattern works for an image, a
diagram, an embed and the `css` option. A script of `Expresso.Builder` uses a variable,
such as `root = Path.expand("..", __DIR__)`. To get the binary, see "Make a binary" in the
README.

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

The first group is in focus at the first step of the code. To show the whole code first,
put `pause()` in front of the code element:

```elixir
slide "the server" do
  pause()

  code "elixir" do
    src "lib/my_app/server.ex"
    lines 40..58
    highlight [40..44, 45..52, 53..58]
  end
end
```

Use `reveal` to show new lines at each step, and `highlight` to point at lines that the
audience already sees. A code element takes one of the two options.

## Make sure that the lines fit

A long line breaks on the slide, and the reader then sees two lines with one number. Open
the document with `?check` at the end of the address, and the report gives each code
element with a line that breaks. See [Check that a deck fits the screen](check-the-layout.md).
