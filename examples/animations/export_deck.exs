defmodule Examples.ExportDeck do
  use Expresso

  name "The release"
  slide_numbers true

  slide "plan" do
    heading "The plan"
    notes "Say the day of each step."

    list do
      reveal true
      item "Freeze the code on Monday"
      item "Test on Tuesday and Wednesday"
      item "Release on Thursday"
    end
  end

  slide "risks" do
    heading "The risks"

    list do
      item "A test that fails late"
      item "A dependency with a new version"
    end
  end
end

Examples.ExportDeck
