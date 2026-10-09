# Point at a part of a slide

This guide shows how to draw a circle, an arrow, a box or a line over a slide, so that the
audience looks at the right part. For each option, see
[The shape element](../reference/shape-element.md).

## Circle a line and add a note

Write a `shape` element for each mark. A percentage is a part of the slide, so
`x: "33%"` is a third of the width from the left edge. Give the shapes an `at` option to
show them after the content:

```elixir
defmodule Examples.Shape do
  use Expresso

  slide "the result" do
    heading "The result"

    code "elixir" do
      text ~S"""
      def total(orders) do
        orders
        |> Enum.map(& &1.price)
        |> Enum.sum()
      end
      """
    end

    shape :ellipse, x: "33%", y: "54.5%", width: "37%", height: "14%", at: [from: 2]

    shape :arrow, from: ["82%", "31%"], to: ["70%", "56%"], at: [from: 2]

    shape :rect do
      at from: 2
      x "66%"
      y "18%"
      width "30%"
      height "12%"
      text "One pass for each order"
      fill true
    end
  end
end

Examples.Shape
```

![At step 2, an ellipse circles a line of code, and an arrow points to it from a note](https://raw.githubusercontent.com/rellen/expresso/media/shape.gif)

To find the place of a shape, look at the slide in the browser, and change the numbers
until the shape covers the part.

## Move an arrow to the next item

Give the shape an `on` entity with `set: [y: ...]` for each step. Use `vh` for the
distance, so the arrow moves the same part of the slide in each window:

```elixir
defmodule Examples.ShapeMove do
  use Expresso

  slide "the plan" do
    heading "The plan"
    steps 3

    list do
      item "Measure the line"
      item "Change one machine"
      item "Measure the line again"
    end

    shape :arrow do
      from ["0.5%", "29.5%"]
      to ["5%", "29.5%"]
      on 2, set: [y: "10vh"]
      on 3, set: [y: "20vh"]
    end
  end
end

Examples.ShapeMove
```

![An arrow points to the first item, then moves down to the second and the third](https://raw.githubusercontent.com/rellen/expresso/media/shape-move.gif)

## Mark a row and change its color

`set: [color: ...]` changes the color of a shape at a step. A color of the theme, such as
`var(--danger)`, changes with the theme. A `:line` under a value marks it:

```elixir
defmodule Examples.ShapeColor do
  use Expresso

  slide "the limit" do
    heading "The limit"

    table do
      header true
      row ["Machine", "Parts each hour"]
      row ["Press", "120"]
      row ["Paint", "45"]
      row ["Pack", "200"]
    end

    shape :rect do
      at from: 2
      x "24%"
      y "45.5%"
      width "53%"
      height "11%"
      on 3, set: [color: "var(--danger)"]
    end

    shape :line, from: ["46%", "54%"], to: ["51.5%", "54%"], at: [from: 3]
  end
end

Examples.ShapeColor
```

![A box shows around the row of the paint machine, then turns red, and a line marks the value](https://raw.githubusercontent.com/rellen/expresso/media/shape-color.gif)
