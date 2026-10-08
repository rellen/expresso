defmodule Examples.VideoAt do
  use Expresso

  slide "the restart" do
    heading "The restart"
    steps 2

    text_box do
      text_area(text: "Watch the test pattern.")
    end

    video "examples/animations/clip.webm" do
      at 2
      title "A test pattern that moves"
      poster "examples/animations/clip.png"
      width "50%"
    end
  end
end

Examples.VideoAt
