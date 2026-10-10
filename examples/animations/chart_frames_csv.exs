defmodule Examples.ChartFramesCsv do
  use Expresso

  root __DIR__

  slide "visitors by year" do
    heading "Visitors by month"

    chart :line do
      title "Visitors each month on the web and in the shop, in 2024 and 2025"
      src "visitors_by_year.csv"
      frames "year"
    end
  end
end

Examples.ChartFramesCsv
