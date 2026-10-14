defmodule Examples.ChartChord do
  use Expresso

  slide "moves" do
    heading "Who moved where"

    chart :chord do
      title "The people that moved between four cities in a year, in thousands"
      value_label "Thousands"
      reveal true

      flow "Northport", "Eastbury", 42
      flow "Northport", "Southvale", 18
      flow "Northport", "Westford", 25
      flow "Eastbury", "Northport", 30
      flow "Eastbury", "Southvale", 12
      flow "Southvale", "Northport", 22
      flow "Southvale", "Westford", 35
      flow "Westford", "Northport", 15
      flow "Westford", "Eastbury", 20
      flow "Westford", "Southvale", 10
    end
  end
end

Examples.ChartChord
