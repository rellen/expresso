defmodule Examples.OverlayAt do
  use Expresso

  slide "at" do
    heading "At a step"

    text_box do
      text_area(text: "Always")
    end

    text_box do
      at from: 2
      text_area(text: "From step 2")
    end

    text_box do
      at 3
      text_area(text: "Only at step 3")
    end
  end
end

Examples.OverlayAt
