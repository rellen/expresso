defmodule Examples.OverlayScale do
  use Expresso

  slide "scale" do
    heading "Grow and turn"

    text_box do
      on [from: 2], set: [scale: 1.5]
      on 3, set: [rotate: "-8deg"]
      text_area(text: "Grow at step 2, and turn at step 3")
    end
  end
end

Examples.OverlayScale
