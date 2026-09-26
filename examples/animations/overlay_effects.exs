defmodule Examples.OverlayEffects do
  use Expresso

  slide "effects" do
    heading "Effects"

    text_box do
      at from: 2
      effect(:grow)
      text_area(text: "Grow at step 2")
    end

    text_box do
      at from: 3
      effect(:fly_up)
      text_area(text: "Fly up at step 3")
    end

    text_box do
      at from: 4
      effect(:fly_left)
      text_area(text: "Fly left at step 4")
    end

    text_box do
      at from: 5
      effect(:wipe)
      text_area(text: "Wipe at step 5")
    end

    text_box do
      at from: 6
      effect(:blur)
      text_area(text: "Blur at step 6")
    end
  end
end

Examples.OverlayEffects
