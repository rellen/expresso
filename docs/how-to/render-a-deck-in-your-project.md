# Render a deck in your project

This guide shows how to keep a deck in your own project, give its paths from the project,
and render it with `mix expresso` or with the binary. For each value of the option, see
[The root option](../reference/root-option.md).

## Give each path from your project

1. Put the deck file in your project, such as `talk/deck.exs`.
2. Give the deck the `root` option with the directory of your project. In the deck file,
   `__DIR__` is the directory of the file, so the directory above it is the project:

   ```elixir
   defmodule MyTalk.Deck do
     use Expresso

     root Path.expand("..", __DIR__)

     slide "the server" do
       code "elixir" do
         src "lib/my_app/server.ex"
         lines from: "def handle_call(", to: "\n  end"
       end
     end
   end
   ```

3. Write each path of the deck from the project, such as `"lib/my_app/server.ex"`. An image,
   a diagram, an embed and the `css` option take their paths from `root` too.

The deck then renders from any directory.

## Render the deck with mix expresso

1. Add Expresso to the dependencies of your project, for the environment `dev` only:

   ```elixir
   defp deps do
     [
       {:expresso, github: "rellen/expresso", only: :dev, runtime: false}
     ]
   end
   ```

2. Fetch the dependencies:

   ```sh
   mix deps.get
   ```

3. Render the deck from the directory of your project:

   ```sh
   mix expresso talk/deck.exs talk/deck.html
   ```

4. To render the deck again after each change, add `--watch`, and open
   `http://127.0.0.1:4100/`:

   ```sh
   mix expresso talk/deck.exs --watch
   ```

Your project does not start Expresso, and a release of your project does not hold it.

## Render the deck with the binary

The binary needs no Elixir, so a computer with no Elixir can render the deck.

1. Make the binary, as "Make a binary" in the README tells, and copy it to a directory on
   your path.
2. Render the deck:

   ```sh
   expresso_cli_app_linux_x86 talk/deck.exs talk/deck.html
   ```

## The complete deck

This deck is next to the file `examples/animations/counter.ex`, so its root is `__DIR__`.
It shows the function `handle_call/3` of the file in two groups:

```elixir
defmodule Examples.ProjectRoot do
  use Expresso

  root __DIR__

  slide "the counter" do
    heading "The counter"

    code "elixir" do
      src "counter.ex"
      lines from: "def handle_call(", to: "\n  end"
      line_numbers true
      reveal [12..13, 14..15]
    end
  end
end

Examples.ProjectRoot
```

![The first two lines of the function show, then the last two lines](https://raw.githubusercontent.com/rellen/expresso/media/project-root.gif)
