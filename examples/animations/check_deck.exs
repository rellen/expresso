defmodule Examples.CheckDeck do
  use Expresso

  css ".quiet { color: #8a8a8a; background: #6b6b6b; padding: 0.2em 0.4em; }"

  slide "the plan" do
    heading "The plan"

    list do
      item "Measure the line"
      item "Find the slowest station"
    end

    text_area(text: "Notes for the speaker go in the notes, not here.", class: "quiet")
  end
end

Examples.CheckDeck
