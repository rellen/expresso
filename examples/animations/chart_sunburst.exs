defmodule Examples.ChartSunburst do
  use Expresso

  root __DIR__

  slide "budget" do
    heading "The budget"

    chart :sunburst do
      title "The budget of the year, by group and by item"
      src "budget.csv"
      at 2
      effect :grow
    end
  end
end

Examples.ChartSunburst
