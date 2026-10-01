# The deck of the stills of the themes. `mix expresso.gifs` renders it one time
# for each built-in theme, and docs/reference/theme-option.md shows each still.
# The still is at step 2 of the slide: the first item is dim, and the progress
# bar is at the end of the deck.
import Expresso.Builder

deck(
  [
    slide("theme",
      heading: "A theme",
      elements: [
        code("elixir",
          text: """
          # Count the slides of a deck
          defmodule Deck do
            def count(%{slides: slides}), do: length(slides) + 1
          end
          """
        ),
        list(reveal: true, dim: true, elements: [item("A dimmed item"), item("The next item")])
      ]
    )
  ],
  slide_numbers: true
)
