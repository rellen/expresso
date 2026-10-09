defmodule Examples.Audio do
  use Expresso

  slide "the signal" do
    heading "The signal"

    text_box do
      text_area do
        text "Each machine of the line plays this chime when it stops."
      end
    end

    audio "examples/animations/chime.ogg" do
      title "The chime of a machine that stops"
      controls true
    end
  end
end

Examples.Audio
