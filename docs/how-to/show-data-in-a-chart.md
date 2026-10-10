# Show data in a chart

This guide shows how to draw a bar chart, a line chart and a pie chart, and how to show the
series of a chart one at a time. For each option, see
[The chart element](../reference/chart-element.md).

## Draw a bar chart and show each series at a step

Write a `chart` element with the kind `:bar`, a `title`, the `categories` and a `series`
for each set of numbers. The `reveal` option shows each series at its own step:

```elixir
defmodule Examples.Chart do
  use Expresso

  slide "orders" do
    heading "Orders each year"

    chart :bar do
      title "Orders and returns each year"
      categories ["2022", "2023", "2024", "2025"]
      reveal true
      series "Orders", [120, 180, 240, 310]
      series "Returns", [14, 22, 19, 25]
    end
  end
end

Examples.Chart
```

![The bars of the orders show at step 1, and the bars of the returns join them at step 2](https://raw.githubusercontent.com/rellen/expresso/media/chart.gif)

The `title` names the chart for a screen reader. The document also holds a table of the
values for a screen reader.

## Draw a line chart from a CSV file

Put the numbers into a CSV file, with the names of the series in the first row and a
category in each other row:

```
Month,Web,Phone,Shop
Jan,420,310,150
Feb,450,360,140
Mar,520,410,160
Apr,610,500,155
May,680,590,170
Jun,720,680,165
```

Give the path of the file in the `src` option. The `dim` option dims each line when the
next line shows, so the audience looks at the new line:

```elixir
defmodule Examples.ChartLine do
  use Expresso

  root __DIR__

  slide "visitors" do
    heading "Visitors each month"

    chart :line do
      title "Visitors each month on the web, by phone and in the shop"
      src "visitors.csv"
      reveal true
      dim true
    end
  end
end

Examples.ChartLine
```

![The line of the web shows first, then the phone and the shop, and the earlier lines dim](https://raw.githubusercontent.com/rellen/expresso/media/chart-line.gif)

## Draw a pie chart

A pie has one series, and each category is a slice. The legend gives each slice in
percent:

```elixir
defmodule Examples.ChartPie do
  use Expresso

  slide "hours" do
    heading "Where the hours go"

    chart :pie do
      title "The hours of a week of the line, by machine"
      categories ["Press", "Paint", "Pack", "Stops"]
      series "Hours", [62, 48, 30, 12]
    end
  end
end

Examples.ChartPie
```

![A pie of four slices, with the name and the part in percent of each slice](https://raw.githubusercontent.com/rellen/expresso/media/chart-pie.png)

A pie shows parts of one whole. To compare values that are close, use a bar chart: an eye
compares the lengths of bars better than the angles of slices.

To move the bars, the lines or the slices of a chart from one point in time to the next, see
[Show a change over time in a chart](show-a-change-over-time-in-a-chart.md).
