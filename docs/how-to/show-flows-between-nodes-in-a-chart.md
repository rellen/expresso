# Show flows between nodes in a chart

This guide shows how to draw a sankey chart. A sankey shows how an amount goes from sources
to targets through other nodes. For each option and each rule of the layout, see
[the charts of flows](../reference/chart-element.md#the-charts-of-flows).

## Draw a sankey from flows

Use flows to give the data in the deck.

1. Write a `chart` element with the kind `:sankey`.
2. Write a `flow` entity for each flow. Give the node where the flow starts, the node where
   it ends, and its value.
3. To show the links one column at a time, add `reveal true`.

A node that is the target of one flow and the source of another flow connects the two flows,
such as "Electricity" here:

```elixir
defmodule Examples.ChartSankey do
  use Expresso

  slide "energy" do
    heading "Where the energy goes"

    chart :sankey do
      title "The energy of a town in a year, from the sources to the users"
      value_label "GWh"
      reveal true

      flow "Coal", "Electricity", 120
      flow "Gas", "Electricity", 95
      flow "Gas", "Heat", 40
      flow "Solar", "Electricity", 30
      flow "Electricity", "Homes", 90
      flow "Electricity", "Industry", 115
      flow "Electricity", "Losses", 40
      flow "Heat", "Homes", 40
    end
  end
end

Examples.ChartSankey
```

![A sankey chart shows the flows from coal, gas and solar to electricity and heat, then from electricity and heat to homes, industry and losses](https://raw.githubusercontent.com/rellen/expresso/media/chart-sankey.gif)

The height of each node and each link shows its value. The table for a screen reader holds
each flow.

## Name, place and style the nodes

Use a `node` entity to change how the chart shows one node.

1. Write a `node` entity with the name of the node in the flows.
2. To change the text of its label, give `label`.
3. To change its color or another style, give `class`, and select the class in the `css`
   option of the deck.
4. To move it, give `column` or `order`.

A funnel shows each stage and the people who leave at each stage. Each node for the people
who leave is gray, and two nodes have longer labels:

```elixir
defmodule Examples.ChartSankeyFunnel do
  use Expresso

  css ".chart-node.drop { fill: var(--muted); }"

  slide "funnel" do
    heading "Where the visitors go"

    chart :sankey do
      title "The visitors of a month, from the first visit to the second year"
      value_label "People"

      flow "Visits", "Trial", 2400
      flow "Visits", "Bounced", 7600
      flow "Trial", "Paid", 600
      flow "Trial", "Left the trial", 1800
      flow "Paid", "Renewed", 450
      flow "Paid", "Cancelled", 150

      node "Bounced", label: "Left after one visit", class: "drop"
      node "Left the trial", class: "drop"
      node "Cancelled", class: "drop"
      node "Renewed", label: "Renewed for a year"
    end
  end
end

Examples.ChartSankeyFunnel
```

![A funnel from 10,000 visits to 2,400 trials, 600 payments and 450 renewals, with a gray node next to each stage for the people who leave](https://raw.githubusercontent.com/rellen/expresso/media/chart-sankey-funnel.png)

For the values of each option, see
[the node entity](../reference/chart-element.md#the-node-entity).

## Show a change over time

Use frames to show the flows at two or more points in time.

1. Write a `frame` entity for each point in time.
2. Put the flows of that point in time into the frame.

Each frame after the first takes one step. At each step, the chart changes slowly from one
frame to the next:

```elixir
defmodule Examples.ChartSankeyFrames do
  use Expresso

  slide "energy" do
    heading "Then and now"

    chart :sankey do
      title "The energy of a town in 2015 and in 2025, from the sources to the users"
      value_label "GWh"

      frame "2015" do
        flow "Coal", "Electricity", 180
        flow "Gas", "Electricity", 60
        flow "Gas", "Heat", 50
        flow "Electricity", "Homes", 110
        flow "Electricity", "Industry", 90
        flow "Electricity", "Losses", 40
        flow "Heat", "Homes", 50
      end

      frame "2025" do
        flow "Coal", "Electricity", 40
        flow "Gas", "Electricity", 70
        flow "Solar", "Electricity", 90
        flow "Gas", "Heat", 35
        flow "Electricity", "Homes", 95
        flow "Electricity", "Industry", 80
        flow "Electricity", "Losses", 25
        flow "Heat", "Homes", 35
      end
    end
  end
end

Examples.ChartSankeyFrames
```

![A sankey chart of 2015 changes into the sankey chart of 2025, in which solar is a new source and coal is much smaller](https://raw.githubusercontent.com/rellen/expresso/media/chart-sankey-frames.gif)

A node stays in its place in each frame. A frame can leave out a flow, such as the flow from
solar in 2015. A chart with frames takes no `reveal`.

## Give the flows in a CSV file

Use a CSV file when the flows come from another tool.

1. Put one flow on each row: the source, the target and the value.
2. Give the headings of the two columns of nodes in the `levels` option.

```
from,to,GWh
Coal,Electricity,120
Gas,Electricity,95
Gas,Heat,40
Electricity,Homes,90
```

```elixir
chart :sankey do
  title "The energy of a town in a year"
  src "energy.csv"
  levels ["from", "to"]
end
```

Two rows with the same source and the same target add their values. Thus a file can hold one
row for each delivery.

To give frames in the file, add a column with the label of the frame of each row. Give its
heading in the `frames` option:

```
year,from,to,GWh
2015,Coal,Electricity,180
2015,Electricity,Homes,180
2025,Coal,Electricity,40
2025,Electricity,Homes,40
```

```elixir
chart :sankey do
  title "The energy of a town"
  src "energy.csv"
  levels ["from", "to"]
  frames "year"
end
```

## Draw an alluvial chart

Use an alluvial chart to show how the same records change from one column to the next. An
example is the answers of the same people in each year.

1. Write a `chart` element with the kind `:alluvial`.
2. Write each category as the path of a group of records, with one name for each column.
3. Give the number of records in each group in the series.
4. To put a title over each column, give the titles in the `levels` option.

```elixir
defmodule Examples.ChartAlluvial do
  use Expresso

  slide "commute" do
    heading "The commute"

    chart :alluvial do
      title "How 1,000 people of the staff got to work in 2020, in 2023 and in 2026"
      value_label "People"
      levels ["2020", "2023", "2026"]
      reveal true

      categories [
        ["Car", "Car", "Car"],
        ["Car", "Car", "Train"],
        ["Car", "Home", "Home"],
        ["Car", "Bike", "Bike"],
        ["Train", "Train", "Train"],
        ["Train", "Home", "Home"],
        ["Train", "Home", "Train"],
        ["Bike", "Bike", "Bike"],
        ["Bike", "Train", "Train"]
      ]

      series "People", [310, 60, 140, 50, 170, 90, 60, 90, 30]
    end
  end
end

Examples.ChartAlluvial
```

![An alluvial chart shows how the staff got to work in 2020, 2023 and 2026: car, train, home and bike in each column, with ribbons between them](https://raw.githubusercontent.com/rellen/expresso/media/chart-alluvial.gif)

Each column has its own node for each name, so a name can go to the same name, such as "Car"
to "Car". A sankey has one node for each name in the whole chart. Thus use `:alluvial` when the
same name can show in two columns.

A CSV file with one row for each group of records gives the same data. The `levels` option
names the CSV columns that hold the path. Their headings are the titles of the chart columns:

```
class,sex,survived,people
First,Female,Yes,141
First,Male,No,118
Third,Female,No,106
Third,Male,No,422
```

```elixir
chart :alluvial do
  title "Who survived the Titanic, by class and by sex"
  src "titanic.csv"
  levels ["class", "sex", "survived"]
end
```

## Show each group in a parallel sets chart

Use a parallel sets chart to see the path of each group of records through all the columns.
In an alluvial chart, a ribbon from "Third" to "Adult" and a ribbon from "Adult" to "No" can
hold different people. In a parallel sets chart, each category is one ribbon from the first
column to the last.

1. Write a `chart` element with the kind `:parallel_sets`.
2. Write each category with one name for each column.
3. Put the names that you compare, such as the class, in the first column.

```elixir
defmodule Examples.ChartParallelSets do
  use Expresso

  slide "titanic" do
    heading "Who survived"

    chart :parallel_sets do
      title "The 2,201 people on the Titanic, by class, by age and by survival"
      value_label "People"
      levels ["Class", "Age", "Survived"]
      reveal true

      categories [
        ["First", "Adult", "Yes"],
        ["First", "Adult", "No"],
        ["First", "Child", "Yes"],
        ["Second", "Adult", "Yes"],
        ["Second", "Adult", "No"],
        ["Second", "Child", "Yes"],
        ["Third", "Adult", "Yes"],
        ["Third", "Adult", "No"],
        ["Third", "Child", "Yes"],
        ["Third", "Child", "No"],
        ["Crew", "Adult", "Yes"],
        ["Crew", "Adult", "No"]
      ]

      series "People", [197, 122, 6, 94, 167, 24, 151, 476, 27, 52, 212, 673]
    end
  end
end

Examples.ChartParallelSets
```

![A parallel sets chart of the Titanic: a ribbon of each class goes through age to survival, and each class shows at its own step](https://raw.githubusercontent.com/rellen/expresso/media/chart-parallel-sets.gif)

Each ribbon has the color of its node in the first column. With `reveal true`, the nodes show
first. Then the ribbons of each node in the first column show at their own step. The `levels`
option, a CSV file, frames and node entities work as in an alluvial chart.

## Correct a loop

A sankey goes in one direction. A flow back to an earlier node gives an error that names
the loop, such as `the flows of a sankey make a loop: Plant → Store → Plant`. To correct the
error, give the second copy of the node its own name, such as "Plant (returns)".
