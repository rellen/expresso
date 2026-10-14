defmodule Examples.ChartSankeyLoop do
  use Expresso

  slide "steel" do
    heading "The loop of steel"

    chart :sankey do
      title "The steel of a region in a year, from the ore to the users and back"
      value_label "kt"

      flow "Ore", "Mill", 700
      flow "Mill", "Products", 900
      flow "Mill", "Scrap", 100
      flow "Scrap", "Mill", 100
      flow "Products", "Landfill", 350
      flow "Products", "Recycling", 550
      flow "Recycling", "Mill", 200
      flow "Recycling", "Export", 350
    end
  end
end

Examples.ChartSankeyLoop
