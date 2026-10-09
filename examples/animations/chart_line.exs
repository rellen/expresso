defmodule Examples.ChartLine do
  use Expresso

  root __DIR__

  slide "visitors" do
    heading "Visitors each month"

    chart :line do
      title "Visitors each month on the web, by phone and in the shop"
      src "visitors.csv"
      reveal true
      dim true
    end
  end
end

Examples.ChartLine
