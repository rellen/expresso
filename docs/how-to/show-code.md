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

## Make sure that the lines fit

A long line breaks on the slide, and the reader then sees two lines with one number. Open
the document with `?check` at the end of the address, and the report gives each code
element with a line that breaks. See [Check that a deck fits the screen](check-the-layout.md).
