defmodule Examples.OverlayRow do
  use Expresso

  slide "rows" do
    heading "Table rows"

    table do
      header true
      row ["Step", "Effect"]
      row ["1", "A plain row"]

      row ["2", "An outline at step 2"] do
        on 2, state: :alert
      end

      row ["3", "A move at step 3"] do
        on [from: 3], set: [x: "60px"]
      end
    end
  end
end

Examples.OverlayRow
