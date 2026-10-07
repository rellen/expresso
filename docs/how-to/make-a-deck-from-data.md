# Make a deck from data

This guide shows how to make the slides of a deck from data, such as a list of topics.
Each section gives a complete script. Render a script with this command:

```sh
mix expresso talk.exs talk.html
```

You can use one of two methods:

| Method | When to use it |
| --- | --- |
| A `for` loop in the DSL | A script makes the deck before the talk. The compiler gives the file and the line of an error. |
| The functions of `Expresso.Builder` | A program makes the deck at runtime, or the deck has very many slides. |

The two methods take the same options, and they make the same deck.

## Use a `for` loop in the DSL

A module of the DSL accepts Elixir code between the entities. Put a `for` loop around the
`slide` entity to make one slide for each item of the data. A second `for` loop in the
`list` entity makes one item for each point:

```elixir
defmodule Examples.TalkFromData do
  use Expresso

  @topics [
    {"Why Elixir", ["Concurrency", "Fault tolerance", "Hot code upgrade"]},
    {"Why the BEAM", ["Processes", "Supervisors", "Distribution"]}
  ]

  name "a talk from data"

  for {title, points} <- @topics do
    slide title do
      heading title

      list do
        reveal true
        for point <- points, do: item(point)
      end
    end
  end
end

Examples.TalkFromData
```

The deck has one slide for each topic, and the items of each slide show one at a time:

![The three points of the first topic show one at a time, then the slide of the second topic shows](https://raw.githubusercontent.com/rellen/expresso/media/talk-from-data.gif)

The data must be available when the module compiles. In a script, the module compiles when
the script runs, so the script can read the data from a file.

## Use the functions of `Expresso.Builder`

`Expresso.Builder` has one function for each entity of the DSL. A function takes the
arguments of the entity, then a keyword list with the options and the children. Make the
slides with `Enum.map/2` or with `for`, then give them to `deck/2`:

```elixir
import Expresso.Builder

topics = [
  {"Why Elixir", ["Concurrency", "Fault tolerance", "Hot code upgrade"]},
  {"Why the BEAM", ["Processes", "Supervisors", "Distribution"]}
]

slides =
  for {title, points} <- topics do
    slide(title,
      heading: title,
      elements: [list(reveal: true, elements: Enum.map(points, &item/1))]
    )
  end

deck(slides, name: "a talk from data")
```

`deck/2` runs the checks of the DSL. It raises an exception for an error, and it writes
each warning to the standard error. The message of an error gives the path of the slide,
but not the file or the line.

## Choose a method for a deck of many slides

A module of the DSL compiles more slowly as the number of slides increases. The functions
of `Expresso.Builder` do not compile the deck. These times come from a deck with one text
box on each slide:

| Slides | `for` loop in the DSL | `Expresso.Builder` |
| --- | --- | --- |
| 50 | 0.4 s | less than 0.1 s |
| 500 | 1.6 s | less than 0.1 s |
| 1000 | 5.9 s | less than 0.1 s |
| 2000 | 33 s | 0.1 s |

For a talk of less than approximately 250 slides, the two methods take less than one
second. For a larger deck, use `Expresso.Builder`.

## Read the data from a file

Replace the list in the script with data from a file, such as `File.read!("topics.csv")`.
The watch mode does not see a file that the script reads. After a change to the data, give
the script a new modification time with `touch talk.exs`. The watch mode then renders the
deck again.

For the options of each entity, see the reference pages, such as
[The overlay options](../reference/overlay-options.md).
