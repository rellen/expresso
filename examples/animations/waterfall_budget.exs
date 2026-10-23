defmodule Examples.WaterfallBudget do
  use Expresso

  slide "budget" do
    heading "Plan and actual"

    chart :waterfall do
      title "The budget of the platform team, in thousands of dollars"
      value_label "Budget (k$)"

      categories [
        "Plan for the year",
        "Two new engineers",
        "Travel to customers",
        "Cloud discount",
        "Actual spend"
      ]

      series "Budget", [900, 60, -30, 4, {:total, 934}]
      direction :horizontal
      value_range {800, 1000}
      highlight ["Two new engineers", ["Plan for the year", "Actual spend"]]
    end
  end
end

Examples.WaterfallBudget
