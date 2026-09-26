defmodule Examples.Tour do
  use Expresso

  name "tour"
  slide_numbers true
  duration 10

  slide "tour" do
    heading "A tour of the presenter"
    notes "Welcome the audience, and press j."

    text_box do
      text_area(text: "Press j for the next step, and k for the step before.")
    end
  end

  slide "steps" do
    heading "Steps"
    auto_reveal true
    notes "Each box is one step of this slide."

    text_box do
      text_area(text: "A slide can have steps.")
    end

    text_box do
      text_area(text: "Each step shows one more element.")
    end

    text_box do
      text_area(text: "A move back hides the last one.")
    end
  end

  slide "list" do
    heading "A list"
    notes "The items come one after the other."

    list do
      reveal true
      item "The first item"
      item "The second item"
      item "The third item"
    end
  end

  slide "quotation" do
    heading "A quotation"

    quotation "Less is more." do
      by "Ludwig Mies van der Rohe"
    end
  end

  slide "table" do
    heading "A table"

    table do
      header true
      row ["Key", "Action"]
      row ["j", "The next step"]
      row ["k", "The step before"]
    end
  end

  slide "end" do
    heading "The end"
    notes "Thank the audience."

    text_box do
      text_area(text: "Press Home for the first slide.")
    end
  end
end

Examples.Tour
