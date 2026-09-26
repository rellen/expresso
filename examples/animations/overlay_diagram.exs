defmodule Examples.OverlayDiagram do
  use Expresso

  slide "diagram" do
    heading "Diagram parts"

    diagram "examples/flow.svg" do
      width "70%"

      part "input" do
        on 2, state: :alert
      end

      part "output" do
        on [from: 3], set: [scale: 1.3, rotate: "10deg"]
      end
    end
  end
end

Examples.OverlayDiagram
