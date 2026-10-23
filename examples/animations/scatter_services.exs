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
