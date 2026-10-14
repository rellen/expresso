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
