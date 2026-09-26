defmodule Examples.OverlayColor do
  use Expresso

  slide "color" do
    heading "Color and opacity"

    text_box do
      on [from: 2], set: [color: "#c92a2a"]
      text_area(text: "This text turns red at step 2")
    end

    text_box do
      on [from: 3], set: [opacity: 0.3]
      text_area(text: "This box fades to 30% at step 3")
    end
  end
end

Examples.OverlayColor
