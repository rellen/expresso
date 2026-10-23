defmodule Examples.ScatterTrend do
  use Expresso

  slide "teams" do
    heading "Tests and defects"

    chart :scatter do
      title "Tests and defects of each module"
      x_label "Tests"
      y_label "Defects a month"
      color_label "Team"
      trend(:linear)
      highlight ["Core", "Edge", "cache"]

      series "Core" do
        point "parser", x: 120, y: 4
        point "renderer", x: 340, y: 2
        point "overlay", x: 210, y: 3
        point "theme", x: 80, y: 6
      end

      series "Edge" do
        symbol :square
        point "cli", x: 60, y: 9
        point "watch", x: 150, y: 6
        point "cache", x: 40, y: 12
        point "release", x: 110, y: 7
      end
    end
  end
end

Examples.ScatterTrend
