defmodule Examples.Video do
  use Expresso

  slide "the demonstration" do
    heading "The demonstration"
    notes "The handout view and paper show the poster in place of the video."

    video "examples/animations/clip.webm" do
      title "A test pattern that moves"
      poster "examples/animations/clip.png"
      width "60%"
    end
  end
end

Examples.Video
