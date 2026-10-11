defmodule Examples.ChartTreemap do
  use Expresso

  slide "hours" do
    heading "Where the hours go"

    chart :treemap do
      title "The hours of a week of the line, by area and by machine"

      categories [
        "Production/Press",
        "Production/Paint",
        "Production/Pack",
        "Support/Maintenance",
        "Support/Stops",
        "Office/Planning",
        "Office/Sales"
      ]

      frame "Week 1" do
        series "Hours", [62, 48, 30, 25, 12, 20, 15]
      end

      frame "Week 2" do
        series "Hours", [44, 52, 46, 18, 30, 22, 10]
      end
    end
  end
end

Examples.ChartTreemap
