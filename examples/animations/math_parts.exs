defmodule Examples.MathParts do
  use Expresso

  slide "the quadratic formula" do
    heading "The quadratic formula"

    math do
      tex ~S"x = \frac{-b \pm \sqrt{\part{disc}{b^2 - 4ac}}}{\part{den}{2a}}"

      part "disc" do
        on [from: 2], set: [color: "var(--accent)"]
      end

      part "den" do
        on 3, state: :alert
      end
    end
  end
end

Examples.MathParts
