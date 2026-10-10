defmodule Examples.ChartGrow do
  use Expresso

  slide "hours" do
    heading "Where the hours go"

    chart :pie do
      title "The hours of a week of the line, by machine"
      categories ["Press", "Paint", "Pack", "Stops"]
      at 2
      effect :grow
      series "Hours", [62, 48, 30, 12]
    end
  end
end

Examples.ChartGrow
