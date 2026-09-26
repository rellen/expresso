defmodule Examples.OverlayAlert do
  use Expresso

  slide "alert" do
    heading "Highlight"
    steps 3

    text_box do
      text_area(text: "A plain box")
    end

    text_box do
      on 2, state: :alert
      text_area(text: "The outline shows at step 2")
    end
  end
end

Examples.OverlayAlert
