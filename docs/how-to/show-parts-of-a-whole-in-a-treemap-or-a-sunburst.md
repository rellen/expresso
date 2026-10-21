# Show the parts of a whole in a treemap or a sunburst

This guide shows how to draw a treemap, a sunburst and a Voronoi treemap, which show the
parts of a whole in groups. For each option, see [The chart element](../reference/chart-element.md).

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

## Give the levels in columns of a CSV file

A file from a spreadsheet often has a column for each level. Give the headings of these
columns in the `levels` option, from the top level down. An empty cell at the end of a row ends
the category at a higher level, so `Office,,20` is a part of the top level:

```
Division,Team,Hours
Production,Press,62
Production,Paint,48
Production,Pack,30
R&D/Test,Lab,26
R&D/Test,Field,14
Office,,20
```

The name of a level can then hold a slash, such as "R&D/Test":

```elixir
defmodule Examples.ChartLevels do
  use Expresso

  root __DIR__

  slide "teams" do
    heading "Hours by team"

    chart :treemap do
      title "The hours of a week, by division and by team"
      src "hours_by_team.csv"
      levels ["Division", "Team"]
    end
  end
end

Examples.ChartLevels
```

![A treemap of three divisions, with the teams of each division in its box](https://raw.githubusercontent.com/rellen/expresso/media/chart-levels.png)

The `frames` option works with the `levels` option. The file then holds the column of the
frame, the columns of the levels and the column of the values.

## Use a different separator, or a list of levels

When the names of your categories hold a slash, give a different text between two levels in
the `separator` option:

```elixir
categories ["I/O > Disks", "I/O > Network", "CPU"]
separator " > "
```

You can also give each category as a list of its levels. A list needs no separator:

```elixir
categories [["I/O", "Disks"], ["I/O", "Network"], ["CPU"]]
```

## Fill a circle, a hexagon or a polygon

Write a `chart` element with the kind `:voronoi`, and give it the data of a treemap. The
`shape` option gives the container: `:rectangle`, `:circle`, `:hexagon`, or the points of a
convex polygon in a unit box. Each part is a cell with an area in proportion to its value,
and each group is the cell that holds its parts:

```elixir
defmodule Examples.ChartVoronoi do
  use Expresso

  slide "staff" do
    heading "Where the staff work"

    chart :voronoi do
      title "The staff of each department, by team"
      shape :hexagon
      highlight ["Production", "Sales", "Sales/Online"]

      categories [
        "Production/Press",
        "Production/Paint",
        "Production/Weld",
        "Production/Pack",
        "Sales/North",
        "Sales/South",
        "Sales/Online",
        "Research/Labs",
        "Research/Field",
        "Office"
      ]

      series "Staff", [42, 18, 25, 12, 30, 22, 12, 16, 8, 14]
    end
  end
end

Examples.ChartVoronoi
```

![A hexagon of cells: the group Production is in focus, then the group Sales, and then its part Online](https://raw.githubusercontent.com/rellen/expresso/media/chart-voronoi.gif)

A polygon must be convex, such as a triangle: `shape [{0, 0}, {1, 0}, {0.5, 1}]`. The y axis
goes down, so this triangle has its corner at the bottom. The compiler refuses a polygon
with a dent. A Voronoi treemap takes no frames, so use a treemap for a change over time.

## Choose the kind

- Use a treemap when the parts are many, or when the reader compares the sizes of parts.
  An eye compares the areas of rectangles better than the angles of arcs.
- Use a sunburst when the levels are the message, such as the share of each group and of
  its parts.
- Use a Voronoi treemap when the chart must fill a shape, such as a circle or a hexagon, or
  when a treemap gives small parts as thin strips. A cell has no fixed direction.
- Use a pie or a bar chart when the data has no groups.
