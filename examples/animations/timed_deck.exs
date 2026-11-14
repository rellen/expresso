defmodule Examples.TimedDeck do
  use Expresso

  name "timed deck"
  advance 20_000
  loop true

  slide "title" do
    advance false
    heading "Three facts about the BEAM"

    text_box do
      text_area(text: "Press j to start the clock.")
    end
  end

  slide "processes" do
    heading "Processes"

    text_box do
      text_area(text: "A process is small, so a node can run millions of them.")
    end
  end

  slide "failures" do
    heading "Failures"

    text_box do
      text_area(text: "A supervisor starts a process again after a failure.")
    end
  end

  slide "upgrades" do
    advance 10_000
    heading "Upgrades"

    text_box do
      text_area(text: "A node can load new code while it runs.")
    end
  end
end

Examples.TimedDeck
