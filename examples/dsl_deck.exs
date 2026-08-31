defmodule DslDeck do
  use Expresso

  name("dsl deck")

  slide "intro" do
    text_box do
      text_area do
        text "A deck from the DSL. Text accepts <b>raw HTML</b>."
      end
    end
  end

  slide do
    text_box do
      text_area do
        text "A slide without a name."
      end
    end
  end
end
