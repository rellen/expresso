defmodule Examples.MathReduce do
  use Expresso

  # Two β-reductions make the next lines. Each reduce finds the leftmost
  # outermost redex, its bound variables and its argument, so the first line
  # needs no names. The second reduce puts its first two phases in one step.

  slide "reduce a term" do
    heading "Reduce a term"

    math do
      reveal true

      line tex: ~S"(\lambda f.\,\lambda x.\,f\,(f\,x))\,g\,y"

      reduce :leftmost

      reduce :leftmost, steps: [[:redex, :bound], :body, :argument]

      # The first line dims when the third line starts.
      part "line1" do
        on [from: 6], state: :dim
      end
    end
  end
end

Examples.MathReduce
