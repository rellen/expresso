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

## Show an element in a different way

Write the `effect` option in the element, next to the `at` option. `:grow` makes the
element larger, `:fly_up` moves it up to its place, `:wipe` opens it from left to right,
and `:blur` makes it sharp. At the end of its steps, the element hides with the same
effect in the other direction.

```elixir
defmodule Examples.OverlayEffects do
  use Expresso

  slide "effects" do
    heading "Effects"

    text_box do
      at from: 2
      effect(:grow)
      text_area(text: "Grow at step 2")
    end

    text_box do
      at from: 3
      effect(:fly_up)
      text_area(text: "Fly up at step 3")
    end

    text_box do
      at from: 4
      effect(:fly_left)
      text_area(text: "Fly left at step 4")
    end

    text_box do
      at from: 5
      effect(:wipe)
      text_area(text: "Wipe at step 5")
    end

    text_box do
      at from: 6
      effect(:blur)
      text_area(text: "Blur at step 6")
    end
  end
end

Examples.OverlayEffects
```

![Each box shows at its step with its own effect](https://raw.githubusercontent.com/rellen/expresso/media/overlay-effects.gif)

## Give the same effect to a group of elements

Write the `effect` option in the parent. Each child without its own `effect` option uses
the effect of the parent. A slide and the deck take the option too, and an element uses
the nearest value. This deck flies each item of the list in, and a step back flies the
last item out.

```elixir
defmodule Examples.OverlayEffectList do
  use Expresso

  slide "effect list" do
    heading "A list that flies in"

    # The items take the effect of the list.
    list do
      reveal true
      effect(:fly_up)
      item "The first point"
      item "The second point"
      item "The third point"
    end
  end
end

Examples.OverlayEffectList
```

![The items fly up one after the other, and the last item flies out after a step back](https://raw.githubusercontent.com/rellen/expresso/media/overlay-effect-list.gif)

## Change the speed of an animation

Write the `speed` option in the element: `:fast`, `:slow` or a number of milliseconds. The
option applies to each animation of the element, such as its effect and the changes of its
`on` entities. A slide and the deck take the option too.

```elixir
defmodule Examples.OverlaySpeed do
  use Expresso

  slide "speed" do
    heading "Speed"

    text_box do
      speed(:fast)
      on 2, set: [x: "300px"]
      text_area(text: "speed :fast")
    end

    text_box do
      on 2, set: [x: "300px"]
      text_area(text: "The default")
    end

    text_box do
      speed(:slow)
      on 2, set: [x: "300px"]
      text_area(text: "speed :slow")
    end

    text_box do
      speed(1200)
      on 2, set: [x: "300px"]
      text_area(text: "speed 1200")
    end
  end
end

Examples.OverlaySpeed
```

![Four boxes move at step 2, each with its own speed](https://raw.githubusercontent.com/rellen/expresso/media/overlay-speed.gif)

## Change the easing of an animation

Write the `easing` option in the element: `:ease_in_out`, `:ease_out`, `:linear` or
`:spring`. This slide gives one second to each element with `speed 1000`, so the
difference is clear.

```elixir
defmodule Examples.OverlayEasing do
  use Expresso

  # The slide gives each element one second, so the easings are clear.
  slide "easing" do
    heading "Easing"
    speed(1000)

    text_box do
      easing(:ease_in_out)
      on 2, set: [x: "300px"]
      text_area(text: "easing :ease_in_out")
    end

    text_box do
      easing(:ease_out)
      on 2, set: [x: "300px"]
      text_area(text: "easing :ease_out")
    end

    text_box do
      easing(:linear)
      on 2, set: [x: "300px"]
      text_area(text: "easing :linear")
    end

    text_box do
      easing(:spring)
      on 2, set: [x: "300px"]
      text_area(text: "easing :spring")
    end
  end
end

Examples.OverlayEasing
```

![Four boxes move at step 2, each with its own easing](https://raw.githubusercontent.com/rellen/expresso/media/overlay-easing.gif)

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

## Grow or turn an element at a step

Write an `on` entity with `set: [scale: ...]` or `set: [rotate: ...]` in the element. A
scale of 1.5 makes the element 50% larger, and an angle turns it. Two `on` entities can
apply at the same step, and the element then grows and turns together.

```elixir
defmodule Examples.OverlayScale do
  use Expresso

  slide "scale" do
    heading "Grow and turn"

    text_box do
      on [from: 2], set: [scale: 1.5]
      on 3, set: [rotate: "-8deg"]
      text_area(text: "Grow at step 2, and turn at step 3")
    end
  end
end

Examples.OverlayScale
```

![The box grows at step 2, and it turns at step 3](https://raw.githubusercontent.com/rellen/expresso/media/overlay-scale.gif)

## Change the color or the opacity of an element

Write an `on` entity with `set: [color: ...]` or `set: [opacity: ...]` in the element. The
color is a CSS color, and the opacity is a number from 0 to 1. The element keeps its place
in the layout at each opacity.

```elixir
defmodule Examples.OverlayColor do
  use Expresso

  slide "color" do
    heading "Color and opacity"

    text_box do
      on [from: 2], set: [color: "#c92a2a"]
      text_area(text: "This text turns red at step 2")
    end

    text_box do
      on [from: 3], set: [opacity: 0.3]
      text_area(text: "This box fades to 30% at step 3")
    end
  end
end

Examples.OverlayColor
```

![The first text turns red at step 2, and the second box fades to 30% at step 3](https://raw.githubusercontent.com/rellen/expresso/media/overlay-color.gif)

## Animate a row of a table

Write an `on` entity in the row, with a `do` block after the cells. A row takes the same
options as an element, so it can get the outline, move, grow and turn.

```elixir
defmodule Examples.OverlayRow do
  use Expresso

  slide "rows" do
    heading "Table rows"

    table do
      header true
      row ["Step", "Effect"]
      row ["1", "A plain row"]

      row ["2", "An outline at step 2"] do
        on 2, state: :alert
      end

      row ["3", "A move at step 3"] do
        on [from: 3], set: [x: "60px"]
      end
    end
  end
end

Examples.OverlayRow
```

![The third row gets an outline at step 2, and the last row moves at step 3](https://raw.githubusercontent.com/rellen/expresso/media/overlay-row.gif)

## Animate a part of a diagram

Give each part an `id` in the SVG file, and write a `part` entity with that `id` in the
diagram. An `on` entity in the part moves, turns or grows it, and the other parts stay in
place. A part turns and grows around its own center. The values of `x` and `y` are in the
units of the SVG file.

An arrow can stay on the box that it points to. Move the box, and then turn and grow the
arrow to the new position of the box. The turn and the growth go around the center of the
arrow, so also move the arrow by half of the move of the box. The start of the arrow then
stays in place. A part with an `at` option, such as the box C, shows from that step.

```elixir
defmodule Examples.OverlayDiagram do
  use Expresso

  slide "diagram" do
    heading "Diagram parts"

    diagram "examples/animations/branch.svg" do
      width "70%"

      part "b" do
        on [from: 2], set: [y: "-40px"]
      end

      # The arrow turns and grows around its center. The move keeps its start
      # at box A, and its tip follows box B.
      part "arrow-b" do
        on [from: 2], set: [y: "-20px", rotate: "-19.5deg", scale: 1.061]
      end

      part "arrow-c", at: [from: 3]
      part "c", at: [from: 3]
    end
  end
end

Examples.OverlayDiagram
```

![Box B moves up, and its arrow turns and grows with it. Box C and its arrow then fade in](https://raw.githubusercontent.com/rellen/expresso/media/overlay-diagram.gif)

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

## Dim the earlier items of a list

Write `dim true` in the list, with `reveal true`. Each item dims when the next item shows,
so the newest item has the attention of the audience. A table takes the same option.

```elixir
defmodule Examples.OverlayDim do
  use Expresso

  slide "dim" do
    heading "Dim the earlier items"

    list do
      reveal true
      dim true
      item "The first point"
      item "The second point"
      item "The third point"
    end
  end
end

Examples.OverlayDim
```

![Each item of the list dims when the next item shows](https://raw.githubusercontent.com/rellen/expresso/media/overlay-dim.gif)

## Dim the earlier lines of code

Write `dim true` in the code element, with the `reveal` option. Each group of lines dims
when the next group shows. A line in no group, such as an empty line, does not dim.

```elixir
defmodule Examples.OverlayDimCode do
  use Expresso

  slide "dim code" do
    heading "Dim the earlier lines"

    code "elixir" do
      reveal [1..3, 5, 6]
      dim true

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

Examples.OverlayDimCode
```

![Each group of lines dims when the next group shows](https://raw.githubusercontent.com/rellen/expresso/media/overlay-dim-code.gif)
