# Show points in a scatter plot

This guide shows how to compare many items on two measures in a scatter plot, how to show
three more values with the symbol, the color and the size of each mark, and how to move the
marks from one point in time to the next. For each option, see
[a scatter plot](../reference/chart-element.md#a-scatter-plot).

## Compare items on two measures

Write a `chart :scatter` with a `point` entity for each item. The options `x` and `y` give its
place, and its name is its label. A category of the `symbol` and of the `color`, such as a
region, gives the mark its symbol and its color, and the `size` gives the area of the mark.
When the symbol and the color take the same category, the chart has one legend, so a reader
who cannot tell the colors apart can tell the groups apart.

`reveal true` shows each category of the color at its own step, and the effect `:grow` grows
each mark from the size 0:

```elixir
defmodule Examples.ScatterServices do
  use Expresso

  slide "services" do
    heading "Cost and load"

    chart :scatter do
      title "Cost and load of each service"
      x_label "Cost per month (USD)"
      y_label "Requests per second"
      symbol_label "Region"
      size_label "Users"
      labels :all
      reveal true
      effect :grow

      point "api", x: 1200, y: 840, symbol: "EU", color: "EU", size: 30_000
      point "jobs", x: 900, y: 150, symbol: "EU", color: "EU", size: 2_000
      point "web", x: 400, y: 2100, symbol: "US", color: "US", size: 120_000
      point "auth", x: 300, y: 900, symbol: "US", color: "US", size: 90_000
      point "search", x: 1800, y: 1300, symbol: "APAC", color: "APAC", size: 60_000
    end
  end
end

Examples.ScatterServices
```

![A scatter plot of five services: the services in Europe show first, then the services in the US, then the service in Asia](https://raw.githubusercontent.com/rellen/expresso/media/scatter-services.gif)

`labels :all` gives each point a label, and each label goes where it covers no other label.
To label some points only, give their names, such as `labels ["web", "search"]`.

## Group the points and show a trend

Put the points of a group into a `series`. The series gives its points its symbol and its
color, and the legend shows it by its name. `trend :linear` draws the least-squares line of
each series. `highlight` puts one series or one point in focus at each step, and the rest of
the chart dims:

```elixir
defmodule Examples.ScatterTrend do
  use Expresso

  slide "teams" do
    heading "Tests and defects"

    chart :scatter do
      title "Tests and defects of each module"
      x_label "Tests"
      y_label "Defects a month"
      color_label "Team"
      trend(:linear)
      highlight ["Core", "Edge", "cache"]

      series "Core" do
        point "parser", x: 120, y: 4
        point "renderer", x: 340, y: 2
        point "overlay", x: 210, y: 3
        point "theme", x: 80, y: 6
      end

      series "Edge" do
        symbol :square
        point "cli", x: 60, y: 9
        point "watch", x: 150, y: 6
        point "cache", x: 40, y: 12
        point "release", x: 110, y: 7
      end
    end
  end
end

Examples.ScatterTrend
```

![A scatter plot of the tests and the defects of eight modules: the series Core is in focus with its trend line, then the series Edge, then the module cache](https://raw.githubusercontent.com/rellen/expresso/media/scatter-trend.gif)

A series takes its options in its block, such as `symbol :square`, because the second
argument of `series` is a list of values.

## Move the points from year to year

Put the points of each year into a CSV file, with a column for the year:

```text
country,year,income,life,people,region
Japan,2000,39,81.2,127,Asia
India,2000,0.44,62.5,1057,Asia
Germany,2000,23.6,78.1,82,Europe
Nigeria,2000,0.57,46.3,122,Africa
...
```

The `frames` option names the column of the year, and each year takes one step. Each mark
moves to its new place and size, and its label moves with it. `x_scale :log` gives a
logarithmic axis, as for an income. A bubble chart needs a size for each point:

```elixir
defmodule Examples.ScatterFrames do
  use Expresso

  root __DIR__

  slide "countries" do
    heading "Income and life"

    chart :bubble do
      title "Income and life expectancy of six countries"
      src "countries.csv"
      x "income"
      y "life"
      size "people"
      color "region"
      frames "year"
      x_scale :log
      x_label "Income per person (thousand USD)"
      y_label "Life expectancy (years)"
      size_label "People (million)"
      labels :all
      opacity 0.8
    end
  end
end

Examples.ScatterFrames
```

![A bubble chart of six countries that moves from 2000 to 2010 and to 2020: the income and the life expectancy of each country grow](https://raw.githubusercontent.com/rellen/expresso/media/scatter-frames.gif)

The numbers of the file are approximations, for the example only.

## Color the points from a number

Give a number as the color of each point, such as the growth of each service. The
`color_scale` option gives the colors: `:sequential` from a light color to `--accent`,
`:diverging` from `--danger` through a neutral middle to `--success`, or two roles of the
theme:

```elixir
slide "growth" do
  chart :scatter do
    title "Cost, load and growth of each service"
    color_label "Growth (%)"
    color_scale :diverging

    point "api", x: 1200, y: 840, color: -8
    point "web", x: 400, y: 2100, color: 0
    point "jobs", x: 900, y: 150, color: 12
  end
end
```

The legend shows the scale with its highest and its lowest value.

## Show many marks in one place

When many marks cover each other, give them an opacity, so an area with many marks looks
darker. A jitter moves each mark by a small part of each axis, the same in each render:

```elixir
slide "requests" do
  chart :scatter do
    title "Time and size of each request"
    opacity 0.6
    jitter 0.02

    point "r1", x: 120, y: 3
    point "r2", x: 120, y: 3
    point "r3", x: 125, y: 4
  end
end
```

The larger marks come first in each group, so a large mark does not hide a small mark.
