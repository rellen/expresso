# Show the parts of a whole in a treemap or a sunburst

This guide shows how to draw a treemap and a sunburst, which show the parts of a whole in
groups. For each option, see [The chart element](../reference/chart-element.md).

## Draw a treemap of groups and their parts

Write a `chart` element with the kind `:treemap`. Put a slash in a category to name a part
of a group: the category `"Production/Press"` is the part "Press" of the group
"Production". Give one series with a value for each part. A group shows the sum of its
parts.

The frames of the other charts also apply. The boxes move to the values of each frame:

```elixir
defmodule Examples.ChartTreemap do
  use Expresso

  slide "hours" do
    heading "Where the hours go"

    chart :treemap do
      title "The hours of a week of the line, by area and by machine"

      categories [
        "Production/Press",
        "Production/Paint",
        "Production/Pack",
        "Support/Maintenance",
        "Support/Stops",
        "Office/Planning",
        "Office/Sales"
      ]

      frame "Week 1" do
        series "Hours", [62, 48, 30, 25, 12, 20, 15]
      end

      frame "Week 2" do
        series "Hours", [44, 52, 46, 18, 30, 22, 10]
      end
    end
  end
end

Examples.ChartTreemap
```

![A treemap of three groups, and the boxes change their sizes from week 1 to week 2](https://raw.githubusercontent.com/rellen/expresso/media/chart-treemap.gif)

The area of each box is in proportion to its value. A group has its name in a strip at its
top, and each part has its name and its value. A label that does not fit its box does not
show, and the table for a screen reader holds each value.

## Draw a sunburst from a CSV file

A CSV file gives the same data. Put the groups and the parts into the first column, with a
slash, and the values into the second column:

```
Item,Budget
Staff/Engineering,420
Staff/Sales,180
Staff/Support,120
Premises/Rent,140
Premises/Power,40
Tools/Licenses,60
Tools/Hardware,45
```

A sunburst draws each level as a ring. The groups make the inner ring, and their parts make
the outer ring. The effect `:grow` opens the sunburst from the top at its step:

```elixir
defmodule Examples.ChartSunburst do
  use Expresso

  root __DIR__

  slide "budget" do
    heading "The budget"

    chart :sunburst do
      title "The budget of the year, by group and by item"
      src "budget.csv"
      at 2
      effect :grow
    end
  end
end

Examples.ChartSunburst
```

![A sunburst opens clockwise from the top, with the groups inside and the items outside](https://raw.githubusercontent.com/rellen/expresso/media/chart-sunburst.gif)

The legend gives each group in percent of the whole.

## Choose the kind

- Use a treemap when the parts are many, or when the reader compares the sizes of parts.
  An eye compares the areas of rectangles better than the angles of arcs.
- Use a sunburst when the levels are the message, such as the share of each group and of
  its parts.
- Use a pie or a bar chart when the data has no groups.
