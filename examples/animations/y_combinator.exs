defmodule Examples.YCombinator do
  use Expresso

  # The proof that Y g is equal to g (Y g), with each step of each
  # β-reduction. Only the first line is written by hand. Each rewrite makes
  # the next line: the occurrences get a color, the kept symbols move down,
  # and a copy of the new content moves into each place. The definition of Y
  # names the parts that the later rewrites use.

  css ".small { font-size: 1rem; }"

  slide "Y is a fix point" do
    heading "Y is a fix point"

    math do
      class "small"
      reveal true

      line tex: ~S"\part{Y}{Y}\,\part{g}{g}"

      rewrite "=",
        replace: "Y",
        by_tex: ~S"""
        \part{lam}{(\lambda f.}\,\part{body}{\part{lamx}{(\lambda x.}\,\part{bodyx}{f\,
        \part{pair}{(x\,x)}}\part{closex}{)}\,\part{arg}{(\lambda x.\,f\,(x\,x))}}\part{close}{)}
        """,
        why: "the definition of Y"

      rewrite ~S"\to_\beta",
        replace: "f",
        within: "body",
        by: "g",
        drop: ["lam", "close", "g"],
        why: "f := g"

      rewrite ~S"\to_\beta",
        replace: "x",
        within: "bodyx",
        by: "arg",
        drop: ["lamx", "closex", "arg"],
        why: ~S"x := λx.g (x x)"

      rewrite ~S"=_\beta", replace: "pair", to: ~S"(\use{Y}\,\use{g})", why: "line 3 =β Y g"

      # An old line dims when the line after the next one starts.
      for {line, step} <- [{"line1", 5}, {"line2", 8}, {"line3", 11}] do
        part line do
          on [from: step], state: :dim
        end
      end
    end
  end
end

Examples.YCombinator
