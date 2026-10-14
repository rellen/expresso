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

## Show the paths of records

Use paths when each record goes through more than two nodes, such as the class, the sex and
the survival of each person.

1. Put one record, or one group of records, on each row of a CSV file.
2. Give the columns of the path in the `levels` option, in the order of the path.

```
class,sex,survived,people
First,Female,Yes,141
First,Male,No,118
Third,Female,No,106
Third,Male,No,422
```

```elixir
chart :sankey do
  title "Who survived the Titanic, by class and by sex"
  src "titanic.csv"
  levels ["class", "sex", "survived"]
end
```

A name is one node in the whole chart. When the same value can show in two columns, give
each column its own names, such as "2024: Red" and "2025: Red".

## Correct a loop

A sankey goes in one direction. A flow back to an earlier node gives an error that names
the loop, such as `the flows of a sankey make a loop: Plant → Store → Plant`. To correct the
error, give the second copy of the node its own name, such as "Plant (returns)".
