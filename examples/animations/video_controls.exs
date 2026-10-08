defmodule Examples.VideoControls do
  use Expresso

  slide "the demonstration" do
    heading "The demonstration"

    video "examples/animations/clip.webm" do
      title "A test pattern that moves"
      poster "examples/animations/clip.png"
      width "60%"
      controls true
    end
  end
end

Examples.VideoControls
