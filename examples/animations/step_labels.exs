defmodule Examples.StepLabels do
  use Expresso

  slide "restart" do
    heading "A worker stops"
    labels ["The tree", "The error", "The restart"]

    list do
      reveal true
      item "The supervisor starts three workers"
      item "One worker stops with an error"
      item "The supervisor starts it again"
    end
  end
end

Examples.StepLabels
