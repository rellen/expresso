defmodule Examples.WaterfallCash do
  use Expresso

  slide "cash" do
    heading "Where the cash went"

    chart :waterfall do
      title "Cash in 2025, in thousands of dollars"
      value_label "Cash (k$)"
      categories ["Start", "Sales", "Services", "Mid year", "Grants", "Interest", "Costs", "End"]
      series "Cash", [50, 40, 30, :total, 10, 20, -50, {:total, 100}]
      reveal true
      spans true
      effect :grow
    end
  end
end

Examples.WaterfallCash
