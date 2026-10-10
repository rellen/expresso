defmodule Examples.ChartFrames do
  use Expresso

  slide "orders by region" do
    heading "Orders by region"

    chart :bar do
      title "Orders by region each year"
      categories ["North", "South", "East", "West"]
      sort true
      count true

      frame "2023" do
        series "Orders", [120, 180, 90, 60]
      end

      frame "2024" do
        series "Orders", [210, 170, 140, 80]
      end

      frame "2025" do
        series "Orders", [230, 150, 260, 120]
      end
    end
  end
end

Examples.ChartFrames
