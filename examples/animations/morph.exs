defmodule Examples.Morph do
  use Expresso

  slide "total" do
    heading "This year"

    stat 1250 do
      label "orders"
    end
  end

  slide "detail" do
    heading "This year"

    columns do
      column do
        stat 1250 do
          label "orders"
        end
      end

      column do
        text_area(text: "Up from 900 last year, and each month grew.")
      end
    end
  end
end

Examples.Morph
