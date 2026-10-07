defmodule Examples.EmbedPage do
  use Expresso

  slide "the problem" do
    heading "The problem"

    text_box do
      text_area(text: "The team counts the orders by hand")
    end
  end

  slide "the demonstration" do
    heading "The demonstration"

    embed "examples/animations/demo.html" do
      title "The page of the orders"
      fallback "examples/animations/demo.png"
      interactive true
      width "60%"
    end
  end
end

Examples.EmbedPage
