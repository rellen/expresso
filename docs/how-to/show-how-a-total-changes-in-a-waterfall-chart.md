# Show how a total changes in a waterfall chart

This guide shows how to explain how one number becomes another number with a waterfall
chart: how to build the total from its changes step by step, how to compare a plan with the
actual result, and how to move the chart from one year to the next. For each option, see
[a waterfall chart](../reference/chart-element.md#a-waterfall-chart).

## Build a total from its changes

Write a `chart :waterfall` with one series. The first value is the start, each other number
is a change, and `:total` marks a total column. The chart calculates each total, so you write
no total two times. To make sure of the data, write `{:total, value}`: the compiler then
refuses the chart when the sum before the total is different.

`reveal true` shows the start and the totals at the first step, and each change at its own
step after it. Each total grows or shrinks with each change, and its value counts. `spans
true` draws an arrow from each total to the next total with the sum of the changes between
them, and the effect `:grow` grows each change from its base:

```elixir
defmodule Examples.WaterfallCash do
  use Expresso

  slide "cash" do
    heading "Where the cash went"

    chart :waterfall do
      title "Cash in 2025, in thousands of dollars"
      value_label "Cash (k$)"
      categories ["Start", "Sales", "Services", "Mid year", "Grants", "Interest", "Costs", "End"]
      series "Cash", [50, 40, 30, :total, 10, 20, -50, {:total, 100}]
      reveal true
      spans true
      effect :grow
    end
  end
end

Examples.WaterfallCash
```

![A waterfall chart of the cash in 2025: the start and the two totals show first, then each change grows from the column before it, and the totals grow with it](https://raw.githubusercontent.com/rellen/expresso/media/waterfall-cash.gif)

To show each later total only when its last change shows, write `totals :complete`.

## Compare a plan with the actual result

When the changes are small and the total is large, cut the value axis with `value_range`. A
break mark then shows that the columns do not start at zero. `direction :horizontal` puts
the categories down the left side, so a long name has room. `highlight` puts one change, or
the plan and the actual result, in focus at each step:

```elixir
defmodule Examples.WaterfallBudget do
  use Expresso

  slide "budget" do
    heading "Plan and actual"

    chart :waterfall do
      title "The budget of the platform team, in thousands of dollars"
      value_label "Budget (k$)"

      categories [
        "Plan for the year",
        "Two new engineers",
        "Travel to customers",
        "Cloud discount",
        "Actual spend"
      ]

      series "Budget", [900, 60, -30, 4, {:total, 934}]
      direction :horizontal
      value_range {800, 1000}
      highlight ["Two new engineers", ["Plan for the year", "Actual spend"]]
    end
  end
end

Examples.WaterfallBudget
```

![A horizontal waterfall chart of a budget from 800 to 1000: the two new engineers are in focus, then the plan and the actual spend](https://raw.githubusercontent.com/rellen/expresso/media/waterfall-budget.gif)

## Move the chart from one year to the next

Put each year into a frame. A CSV file can hold the frames: the `frames` option names the
column of the year, the next column holds the category, and the last column holds the values.
A cell holds a change, `total`, or `total` and the value that the sum must agree with. The
`root` option of the deck makes the path of the file relative to the deck:

```
year,Quarter,Cash
2024,Start,50
2024,Sales,40
2024,Services,30
2024,Costs,-60
2024,End,total
2025,Start,60
2025,Sales,55
2025,Services,20
2025,Costs,-45
2025,End,total 90
```

```elixir
defmodule Examples.WaterfallYears do
  use Expresso

  root __DIR__

  slide "years" do
    heading "Two years of cash"

    chart :waterfall do
      title "Cash in 2024 and 2025, in thousands of dollars"
      src "waterfall_years.csv"
      frames "year"
      value_label "Cash (k$)"
    end
  end
end

Examples.WaterfallYears
```

![A waterfall chart that moves from 2024 to 2025: each column moves to its new place, and the totals count to their new values](https://raw.githubusercontent.com/rellen/expresso/media/waterfall-years.gif)

At the step of each later frame, each column moves to its place in that frame, and the
totals count to their new values. Each frame has its totals at the same categories.

## Change the colors

A total takes `--waterfall-total`, an increase `--waterfall-up` and a decrease
`--waterfall-down`. Set them in [the css option](../reference/css-option.md) of the deck:

```elixir
css ".chart-waterfall { --waterfall-total: var(--chart-3); --waterfall-down: var(--warning); }"
```
