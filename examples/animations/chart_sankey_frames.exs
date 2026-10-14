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
