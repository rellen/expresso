defmodule Examples.ScatterFrames do
  use Expresso

  root __DIR__

  slide "countries" do
    heading "Income and life"

    chart :bubble do
      title "Income and life expectancy of six countries"
      src "countries.csv"
      x "income"
      y "life"
      size "people"
      color "region"
      frames "year"
      x_scale :log
      x_label "Income per person (thousand USD)"
      y_label "Life expectancy (years)"
      size_label "People (million)"
      labels :all
      opacity 0.8
    end
  end
end

Examples.ScatterFrames
