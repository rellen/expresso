defmodule Examples.OverlayDiagram do
  use Expresso

  slide "diagram" do
    heading "Diagram parts"

    diagram "examples/animations/branch.svg" do
      width "70%"

      part "b" do
        on [from: 2], set: [y: "-40px"]
      end

      # The arrow turns and grows around its center. The move keeps its start
      # at box A, and its tip follows box B.
      part "arrow-b" do
        on [from: 2], set: [y: "-20px", rotate: "-19.5deg", scale: 1.061]
      end

      part "arrow-c", at: [from: 3]
      part "c", at: [from: 3]
    end
  end
end

Examples.OverlayDiagram
