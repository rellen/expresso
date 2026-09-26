defmodule Examples.OverlayEffectList do
  use Expresso

  slide "effect list" do
    heading "A list that flies in"

    # The items take the effect of the list.
    list do
      reveal true
      effect(:fly_up)
      item "The first point"
      item "The second point"
      item "The third point"
    end
  end
end

Examples.OverlayEffectList
