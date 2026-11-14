defmodule Examples.BackupSlides do
  use Expresso

  name "Backup slides"
  slide_numbers true

  slide "title" do
    heading "The cost of a cache"
  end

  slide "result" do
    heading "The cache halves the cost"

    text_box do
      text_area(text: "See the numbers", goto: [slide: "numbers"])
    end
  end

  slide "numbers" do
    hidden true
    heading "The numbers of each year"
  end

  slide "end" do
    heading "Questions?"
  end
end

Examples.BackupSlides
