defmodule Examples.TransitionOverride do
  use Expresso

  transition :fade

  slide "one" do
    heading "One"

    text_box do
      text_area(text: "The deck fades")
    end
  end

  slide "two" do
    heading "Two"
    transition :slide

    text_box do
      text_area(text: "This slide slides in")
    end
  end

  slide "three" do
    heading "Three"

    text_box do
      text_area(text: "This slide fades in")
    end
  end
end

Examples.TransitionOverride
