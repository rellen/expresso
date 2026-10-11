defmodule Examples.ChartTsv do
  use Expresso

  root __DIR__

  slide "plants" do
    heading "Orders at each plant"

    chart :bar do
      title "Orders and returns at each plant this year"
      src "orders_by_plant.tsv"
    end
  end
end

Examples.ChartTsv
