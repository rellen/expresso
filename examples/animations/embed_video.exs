defmodule Examples.EmbedVideo do
  use Expresso

  slide "the demonstration" do
    heading "The demonstration"
    notes "The handout view and paper show the screenshot in place of the video."

    embed "examples/animations/clip.html" do
      title "A test pattern that moves"
      fallback "examples/animations/clip.png"
      width "60%"
    end
  end
end

Examples.EmbedVideo
