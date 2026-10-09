defmodule Examples.AudioHandout do
  use Expresso

  slide "the signal" do
    heading "The signal"
    notes "Play the chime, then ask what it means."

    audio "examples/animations/chime.ogg" do
      title "The chime of a machine that stops"
    end
  end
end

Examples.AudioHandout
