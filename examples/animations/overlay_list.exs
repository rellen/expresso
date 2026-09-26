defmodule Examples.OverlayList do
  use Expresso

  slide "list" do
    heading "A list"

    list do
      reveal true
      item "The first point"
      item "The second point"
      item "The third point"
    end
  end
end

Examples.OverlayList
