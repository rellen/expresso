defmodule Examples.MathLines do
  use Expresso

  slide "complete the square" do
    heading "Complete the square"

    math do
      reveal true
      line tex: ~S"x^2 + 6x + 5 = 0"
      line ~S"\iff", tex: ~S"x^2 + 6x + 9 = 4", why: "add 4"
      line ~S"\iff", tex: ~S"(x + 3)^2 = 4", why: "a square"
      line ~S"\iff", tex: ~S"x + 3 = \pm 2", why: "a root"
      line ~S"\iff", tex: ~S"x = -1 \text{ or } x = -5"
    end
  end
end

Examples.MathLines
