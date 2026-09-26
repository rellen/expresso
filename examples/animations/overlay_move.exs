defmodule Examples.OverlayMove do
  use Expresso

  slide "move" do
    heading "Move"

    text_box do
      on [from: 2], set: [x: "-300px"]
      text_area(text: "This box moves left at step 2")
    end
  end
end

Examples.OverlayMove
