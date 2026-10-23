defmodule Examples.WaterfallYears do
  use Expresso

  root __DIR__

  slide "years" do
    heading "Two years of cash"

    chart :waterfall do
      title "Cash in 2024 and 2025, in thousands of dollars"
      src "waterfall_years.csv"
      frames "year"
      value_label "Cash (k$)"
    end
  end
end

Examples.WaterfallYears
