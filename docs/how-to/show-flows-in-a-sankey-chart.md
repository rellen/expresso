# Show flows in a sankey chart

This guide shows how to draw a sankey chart, which shows how an amount flows from sources
to targets. For each option, see [The chart element](../reference/chart-element.md).

## Draw a sankey from flows

Write a `chart` element with the kind `:sankey`. Give each flow as a `flow` entity: the
node where the flow starts, the node where it ends, and its value. A node that is a target
of one flow and a source of another flow connects them, such as "Electricity" here.

`reveal true` shows the links one column at a time, from left to right. Each node shows
with the first link that touches it:

```elixir
defmodule Examples.ChartSankey do
  use Expresso

  slide "energy" do
    heading "Where the energy goes"

    chart :sankey do
      title "The energy of a town in a year, from the sources to the users"
      value_label "GWh"
      reveal true

      flow("Coal", "Electricity", 120)
      flow("Gas", "Electricity", 95)
      flow("Gas", "Heat", 40)
      flow("Solar", "Electricity", 30)
      flow("Electricity", "Homes", 90)
      flow("Electricity", "Industry", 115)
      flow("Electricity", "Losses", 40)
      flow("Heat", "Homes", 40)
    end
  end
end

Examples.ChartSankey
```

![A sankey chart shows the flows from coal, gas and solar to electricity and heat, then from electricity and heat to homes, industry and losses](https://raw.githubusercontent.com/rellen/expresso/media/chart-sankey.gif)

The height of each node and each link is in proportion to its value. A node in the first
column has no flow into it, and each other node is one column after its furthest source. A
label shows the name and the value of its node. A label that does not fit its node does not
show, and the table for a screen reader holds each flow.

## Give the flows in a CSV file

Put one flow on each row: the source, the target and the value. Give the headings of the
two columns of the nodes in the `levels` option:

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

Two rows with the same source and the same target add their values, so a file can hold one
row for each delivery.

## Draw an alluvial chart from records

A record with a value in each of some columns is a path through those columns. Give the
columns in the `levels` option, in the order of the path. The chart then shows how the
records divide at each column:

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

A name is one node in the whole chart. Give two columns different names for their values,
such as "2024: Red" and "2025: Red", when the same value shows in two columns.

## Correct a loop

A sankey goes in one direction. A flow back to an earlier node gives an error that names
the loop, such as `the flows of a sankey make a loop: Plant → Store → Plant`. Give the
second copy of the node its own name, such as "Plant (returns)".
