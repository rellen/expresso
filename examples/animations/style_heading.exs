defmodule Examples.StyleHeading do
  use Expresso

  css ~S"""
  :root { --slide-padding: 0 2rem; }
  .aside h1 { text-align: left; }
  """

  slide "the plan" do
    heading "The plan"

    text_box do
      text_area(text: "Each slide has its heading in the center")
    end
  end

  slide "a note" do
    class "aside"
    heading "A note"

    text_box do
      text_area(text: "The class aside puts this heading at the left")
    end
  end
end

Examples.StyleHeading
