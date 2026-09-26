defmodule Examples.OverlayEasing do
  use Expresso

  # The slide gives each element one second, so the easings are clear.
  slide "easing" do
    heading "Easing"
    speed(1000)

    text_box do
      easing(:ease_in_out)
      on 2, set: [x: "300px"]
      text_area(text: "easing :ease_in_out")
    end

    text_box do
      easing(:ease_out)
      on 2, set: [x: "300px"]
      text_area(text: "easing :ease_out")
    end

    text_box do
      easing(:linear)
      on 2, set: [x: "300px"]
      text_area(text: "easing :linear")
    end

    text_box do
      easing(:spring)
      on 2, set: [x: "300px"]
      text_area(text: "easing :spring")
    end
  end
end

Examples.OverlayEasing
