defmodule Examples.ChartLabels do
  use Expresso

  root __DIR__

  slide "visitors" do
    heading "Visitors each month"

    chart :line do
      title "Visitors each month on the web, by phone and in the shop"
      src "visitors.csv"
      value_label "Visitors"
    end
  end
end

Examples.ChartLabels
