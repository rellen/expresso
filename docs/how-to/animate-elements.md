# Animate elements in a slide

This guide shows how to animate the elements of one slide with overlays. An overlay
divides a slide into steps, and each key moves one step forward. Each section gives a
complete deck and a recording of it. The recording presses `j` for the next step.

For each form of the options, see [The overlay options](../reference/overlay-options.md).
For the design, see [Overlays](../overlays.md).

## Show an element from a step

Write the `at` option in the element. The element fades in at the first step of the option,
and it fades out after the last step. `at from: 2` shows the element from step 2 to the end
of the slide. `at 3` shows the element at step 3 only.

```elixir
defmodule Examples.OverlayAt do
  use Expresso

  slide "at" do
    heading "At a step"

    text_box do
      text_area(text: "Always")
    end

    text_box do
      at from: 2
      text_area(text: "From step 2")
    end

    text_box do
      at 3
      text_area(text: "Only at step 3")
    end
  end
end

Examples.OverlayAt
```

![The second box fades in at step 2, and the third box at step 3](https://raw.githubusercontent.com/rellen/expresso/media/overlay-at.gif)

## Highlight an element at a step

Write an `on` entity with `state: :alert` in the element. The theme draws an outline around
the element at those steps.

```elixir
defmodule Examples.OverlayAlert do
  use Expresso

  slide "alert" do
    heading "Highlight"
    steps 3

    text_box do
      text_area(text: "A plain box")
    end

    text_box do
      on 2, state: :alert
      text_area(text: "The outline shows at step 2")
    end
  end
end

Examples.OverlayAlert
```

![An outline fades in around the second box at step 2, and fades out at step 3](https://raw.githubusercontent.com/rellen/expresso/media/overlay-alert.gif)

## Move an element at a step

Write an `on` entity with `set: [x: ..., y: ...]` in the element. The element moves by that
distance at those steps. The move does not change the layout of the other elements.

```elixir
defmodule Examples.OverlayMove do
  use Expresso

  slide "move" do
    heading "Move"

    text_box do
      on [from: 2], set: [x: "-300px"]
      text_area(text: "This box moves left at step 2")
    end
  end
end

Examples.OverlayMove
```

![The box moves to the left at step 2](https://raw.githubusercontent.com/rellen/expresso/media/overlay-move.gif)

## Show a list one item at a time

Write `reveal true` in the list. Each item shows at its own step. A table takes the same
option, and each row then shows at its own step.

```elixir
defmodule Examples.OverlayList do
  use Expresso

  slide "list" do
    heading "A list"

    list do
      reveal true
      item "The first point"
      item "The second point"
      item "The third point"
    end
  end
end

Examples.OverlayList
```

![The three items of the list show one after the other](https://raw.githubusercontent.com/rellen/expresso/media/overlay-list.gif)

## Show code in groups of lines

Write the `reveal` option in the code element, with one group of line numbers for each step.
A line that does not show keeps its space, so the code does not move.

```elixir
defmodule Examples.OverlayCode do
  use Expresso

  slide "code" do
    heading "Code"

    code "elixir" do
      reveal [1..3, 5..6]

      text ~S"""
      defmodule Greeter do
        def greet(name), do: "Hello, #{name}!"
      end

      Greeter.greet("world")
      |> IO.puts()
      """
    end
  end
end

Examples.OverlayCode
```

![The last two lines of the code fade in at step 2](https://raw.githubusercontent.com/rellen/expresso/media/overlay-code.gif)
