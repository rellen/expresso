defmodule Examples.CssFiles do
  use Expresso

  root __DIR__
  css "styles/band.css"

  slide "one" do
    heading "A band from a file"
    text_area(text: "The style sheet names the picture with url().")
  end

  slide "two" do
    heading "The same band"
    text_area(text: "The document holds the picture one time.")
  end
end

Examples.CssFiles
