defmodule Examples.Footnote do
  use Expresso

  slide "the claim" do
    heading "Small decks win"

    text_box do
      text_area do
        text "Talks with fewer than 20 slides got the best reviews.<sup>1</sup>"
      end
    end

    footnote "The reviews of a conference in 2024, from 312 talks."
  end
end

Examples.Footnote
