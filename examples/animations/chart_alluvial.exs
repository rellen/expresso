defmodule Examples.ChartAlluvial do
  use Expresso

  slide "commute" do
    heading "The commute"

    chart :alluvial do
      title "How 1,000 people of the staff got to work in 2020, in 2023 and in 2026"
      value_label "People"
      levels ["2020", "2023", "2026"]
      reveal true

      categories [
        ["Car", "Car", "Car"],
        ["Car", "Car", "Train"],
        ["Car", "Home", "Home"],
        ["Car", "Bike", "Bike"],
        ["Train", "Train", "Train"],
        ["Train", "Home", "Home"],
        ["Train", "Home", "Train"],
        ["Bike", "Bike", "Bike"],
        ["Bike", "Train", "Train"]
      ]

      series "People", [310, 60, 140, 50, 170, 90, 60, 90, 30]
    end
  end
end

Examples.ChartAlluvial
