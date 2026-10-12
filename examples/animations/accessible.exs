defmodule Examples.Accessible do
  use Expresso

  name "Supervisors"

  slide "start" do
    heading "Supervisors"
    labels ["The question"]
    text_area(text: "What happens when a process crashes?")
  end

  slide "restart" do
    heading "A restart"
    labels ["The crash", "The restart"]

    list do
      reveal true
      item "The process crashes"
      item "The supervisor starts it again"
    end
  end

  slide "result" do
    heading "The result"

    stat 99.9 do
      suffix "%"
      label "of the time, the service answers"
    end
  end
end

Examples.Accessible
