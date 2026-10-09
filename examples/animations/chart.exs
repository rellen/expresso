defmodule Examples.Chart do
  use Expresso

  slide "orders" do
    heading "Orders each year"

    chart :bar do
      title "Orders and returns each year"
      categories ["2022", "2023", "2024", "2025"]
      reveal true
      series "Orders", [120, 180, 240, 310]
      series "Returns", [14, 22, 19, 25]
    end
  end
end

Examples.Chart
