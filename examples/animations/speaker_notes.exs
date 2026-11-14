defmodule Examples.SpeakerNotes do
  use Expresso

  slide "restart" do
    heading "A worker stops"

    notes """
    Go **slow** on this slide.

    - Name the three workers
    - Do not show the code
    """

    list do
      reveal true
      item "The supervisor starts three workers"
      item "One worker stops with an error"
      item "The supervisor starts it again"
    end

    note "Ask: *who saw this error before?*", at: 2
    note "Show the log with `mix run`. Then go to the next slide.", at: 3
  end
end

Examples.SpeakerNotes
