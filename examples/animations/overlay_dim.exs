defmodule Examples.OverlayDim do
  use Expresso

  slide "dim" do
    heading "Dim the earlier items"

    list do
      reveal true
      dim true
      item "The first point"
      item "The second point"
      item "The third point"
    end
  end
end

Examples.OverlayDim
