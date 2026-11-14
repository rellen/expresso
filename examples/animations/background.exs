defmodule Examples.Background do
  use Expresso

  name "The evening shift"
  root __DIR__
  theme :dracula

  slide "title" do
    background image: "dusk.png", dim: 0.5
    heading "The evening shift"

    text_box do
      text_area(text: "What a team does after the sun goes down")
    end
  end

  slide "part" do
    background gradient: [:accent, :background], angle: 135, dim: 0.4
    heading "Part 1: the plan"
  end

  slide "plan" do
    heading "The plan"

    list do
      item "Look at the alerts of the day"
      item "Start the long jobs"
      item "Write the notes for the morning"
    end
  end
end

Examples.Background
