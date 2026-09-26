defmodule Examples.OverlaySpeed do
  use Expresso

  slide "speed" do
    heading "Speed"

    text_box do
      speed(:fast)
      on 2, set: [x: "300px"]
      text_area(text: "speed :fast")
    end

    text_box do
      on 2, set: [x: "300px"]
      text_area(text: "The default")
    end

    text_box do
      speed(:slow)
      on 2, set: [x: "300px"]
      text_area(text: "speed :slow")
    end

    text_box do
      speed(1200)
      on 2, set: [x: "300px"]
      text_area(text: "speed 1200")
    end
  end
end

Examples.OverlaySpeed
