defmodule Examples.MathRule do
  use Expresso

  # Two rewrites make the next lines. A rule with variables expands the
  # product, and a substitution puts the value of x into each place.

  slide "apply a rule" do
    heading "Apply a rule"

    math do
      reveal true

      line tex: ~S"k\,(x + h)"

      rewrite rule: {~S"a\,(b + c)", ~S"a \cdot b + a \cdot c"},
              vars: ~w(a b c),
              why: "distribute"

      rewrite replace: "x", by_tex: "2", why: "x := 2"

      # The first line dims when the third line starts.
      part "line1" do
        on [from: 5], state: :dim
      end
    end
  end
end

Examples.MathRule
