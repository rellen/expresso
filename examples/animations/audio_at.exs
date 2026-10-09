defmodule Examples.AudioAt do
  use Expresso

  slide "the stop" do
    heading "The stop"

    text_box do
      text_area do
        text "The line runs."
      end
    end

    text_box do
      at from: 2

      text_area do
        text "A machine stops, and the chime plays."
      end
    end

    audio "examples/animations/chime.ogg" do
      at from: 2
      title "The chime of a machine that stops"
    end
  end
end

Examples.AudioAt
