defmodule Examples.ChartVoronoi do
  use Expresso

  slide "staff" do
    heading "Where the staff work"

    chart :voronoi do
      title "The staff of each department, by team"
      shape :hexagon
      highlight ["Production", "Sales", "Sales/Online"]

      categories [
        "Production/Press",
        "Production/Paint",
        "Production/Weld",
        "Production/Pack",
        "Sales/North",
        "Sales/South",
        "Sales/Online",
        "Research/Labs",
        "Research/Field",
        "Office"
      ]

      series "Staff", [42, 18, 25, 12, 30, 22, 12, 16, 8, 14]
    end
  end
end

Examples.ChartVoronoi
