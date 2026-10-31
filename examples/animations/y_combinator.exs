defmodule Examples.YCombinator do
  use Expresso

  # The proof that Y g is equal to g (Y g), with each step of each
  # β-reduction. Only the first line is written by hand. A rewrite unfolds
  # the definition of Y, each reduce makes the next line by one β-reduction
  # of the leftmost outermost redex, and a rule folds the last line. The
  # definition of Y needs no names, because each reduce finds the λ, the
  # bound variables and the argument of its redex.

  css ".small { font-size: 1rem; }"

  slide "Y is a fix point" do
    heading "Y is a fix point"

    math do
      class "small"
      reveal true

      line tex: ~S"\part{Y}{Y}\,g"

      rewrite "=",
        replace: "Y",
        by_tex: ~S"(\lambda f.\,(\lambda x.\,f\,(x\,x))\,(\lambda x.\,f\,(x\,x)))",
        why: "the definition of Y"

      reduce :leftmost
      reduce :leftmost

      # The argument of g is a term applied to itself: the line 3.
      rewrite ~S"=_\beta",
        rule: {~S"a\,a", ~S"\use{Y}\,g"},
        vars: ["a"],
        why: "line 3 =β Y g"

      # An old line dims when the line after the next one starts.
      for {line, step} <- [{"line1", 5}, {"line2", 9}, {"line3", 13}] do
        part line do
          on [from: step], state: :dim
        end
      end
    end
  end
end

Examples.YCombinator
