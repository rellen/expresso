defmodule Examples.TransitionSlide do
  use Expresso

  transition :slide

  slide "one" do
    heading "One"

    text_box do
      text_area(text: "The first slide")
    end
  end

  slide "two" do
    heading "Two"

    text_box do
      text_area(text: "The second slide")
    end
  end
end

Examples.TransitionSlide
