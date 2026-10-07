defmodule Examples.DiagramMoveTo do
  use Expresso

  slide "the line" do
    heading "The paint line"

    diagram "examples/animations/line.svg" do
      width "70%"

      part "widget" do
        on 2, move_to: "booth"
        on 3, move_to: "dryer"
        on [from: 4], move_to: "packer", set: [scale: 1.5]
      end
    end
  end
end

Examples.DiagramMoveTo
