defmodule Examples.ShapeMove do
  use Expresso

  slide "the plan" do
    heading "The plan"
    steps 3

    list do
      item "Measure the line"
      item "Change one machine"
      item "Measure the line again"
    end

    shape :arrow do
      from ["0.5%", "29.5%"]
      to ["5%", "29.5%"]
      on 2, set: [y: "10vh"]
      on 3, set: [y: "20vh"]
    end
  end
end

Examples.ShapeMove
