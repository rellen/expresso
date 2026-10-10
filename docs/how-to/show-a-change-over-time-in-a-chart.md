# Show a change over time in a chart

This guide shows how to move the bars, the lines and the slices of a chart from one point in
time to the next at each step, and how to grow a chart when it shows. For each option, see
[The chart element](../reference/chart-element.md).

## Move the bars of a chart from year to year

Put the series of each point in time into a `frame` entity. The label of the frame, such as
`"2023"`, shows at the top of the chart. The first frame shows with the chart, and each later
frame takes one step. The bars move to the values of each frame, and a step back moves them
back.

The `sort` option puts the bars of each frame in order of their values, so a category that
grows moves to the front. The `count` option counts each number from one value to the next:

```elixir
defmodule Examples.ChartFrames do
  use Expresso

  slide "orders by region" do
    heading "Orders by region"

    chart :bar do
      title "Orders by region each year"
      categories ["North", "South", "East", "West"]
      sort true
      count true

      frame "2023" do
        series "Orders", [120, 180, 90, 60]
      end

      frame "2024" do
        series "Orders", [210, 170, 140, 80]
      end

      frame "2025" do
        series "Orders", [230, 150, 260, 120]
      end
    end
  end
end

Examples.ChartFrames
```

![The bars of four regions move from 2023 to 2024 and to 2025, East moves to the front, and each number counts to its new value](https://raw.githubusercontent.com/rellen/expresso/media/chart-frames.gif)

Each frame holds the same series, with the same names in the same order. Only the series of
the first frame take the overlay options, such as `at`, so `reveal true` shows each series at
its own step before the second frame.

## Move a line chart through the frames of a CSV file

Put a column for the frame into the CSV file, and give its heading in the `frames` option. Of
the other columns, the first holds the category, and each other column holds a series:

```
year,month,Web,Shop
2024,Jan,420,150
2024,Feb,450,140
2024,Mar,520,160
2024,Apr,610,155
2025,Jan,480,140
2025,Feb,560,120
2025,Mar,690,110
2025,Apr,820,95
```

The rows of one frame make the frame, and the frames have the order of the file:

```elixir
defmodule Examples.ChartFramesCsv do
  use Expresso

  root __DIR__

  slide "visitors by year" do
    heading "Visitors by month"

    chart :line do
      title "Visitors each month on the web and in the shop, in 2024 and 2025"
      src "visitors_by_year.csv"
      frames "year"
    end
  end
end

Examples.ChartFramesCsv
```

![The lines of the web and of the shop move from 2024 to 2025, and the web grows](https://raw.githubusercontent.com/rellen/expresso/media/chart-frames-csv.gif)

The axis holds each value of each frame, so it does not change from frame to frame, and a
change of a line is a change of its value.

## Grow a chart when it shows

Give the chart the effect `:grow`. A bar then grows from the base line, a line opens from the
left and a pie opens from the top:

```elixir
defmodule Examples.ChartGrow do
  use Expresso

  slide "hours" do
    heading "Where the hours go"

    chart :pie do
      title "The hours of a week of the line, by machine"
      categories ["Press", "Paint", "Pack", "Stops"]
      at 2
      effect :grow
      series "Hours", [62, 48, 30, 12]
    end
  end
end

Examples.ChartGrow
```

![The pie opens clockwise from the top at step 2](https://raw.githubusercontent.com/rellen/expresso/media/chart-grow.gif)

The effect needs a step at which the chart shows, such as `at 2`. A series with the effect
`:grow` and `reveal true` grows at its own step.

## Print the frames

On paper and in the handout view, a chart with frames shows each frame as a small chart in a
grid, with its label. Each small chart has the axis of the whole chart, so the reader can
compare them. A slide with a chart with frames has a page for each frame. Give the slide
`handout :last` to print one page with the grid.
