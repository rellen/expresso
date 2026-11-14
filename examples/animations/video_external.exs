defmodule Examples.VideoExternal do
  use Expresso

  slide "the recording" do
    heading "The recording"

    video "examples/animations/clip.webm" do
      title "A test pattern that moves"
      poster "examples/animations/clip.png"
      width "60%"
      external true
    end
  end
end

Examples.VideoExternal
