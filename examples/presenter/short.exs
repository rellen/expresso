defmodule Examples.Short do
  use Expresso

  name "short"

  slide "one" do
    heading "One"

    text_box do
      text_area(text: "The progress bar is at the bottom.")
    end
  end

  slide "two" do
    heading "Two"

    text_box do
      text_area(text: "Each step moves it.")
    end
  end

  slide "three" do
    heading "Three"

    text_box do
      text_area(text: "Each step counts one time.")
    end
  end

  slide "four" do
    heading "Four"

    text_box do
      text_area(text: "The bar is full at the last step.")
    end
  end
end

Examples.Short
