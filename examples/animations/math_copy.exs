defmodule Examples.MathCopy do
  use Expresso

  css ".small { font-size: 1.25rem; }"

  slide "copy the argument" do
    heading "Copy the argument"

    math do
      class "small"

      line tex: ~S"(\lambda \part{bind}{f}.\,\part{f1}{f}\,(\part{f2}{f}\,x))\,\part{arg}{g}"

      line ~S"\to_\beta",
        tex: ~S"\part{h1}{g}\,(\part{h2}{g}\,x)",
        why: "f := g",
        name: "reduced"

      part "bind" do
        on [from: 2], set: [color: "var(--accent)"]
      end

      for bound <- ["f1", "f2"] do
        part bound do
          on [from: 2], set: [color: "var(--accent)"]
        end
      end

      part "arg" do
        on [from: 2], set: [color: "var(--success)"]
        on 3, copy_to: ["h1", "h2"]
      end

      part "line1" do
        on [from: 4], state: :dim
      end

      part "reduced", at: [from: 3]

      for hole <- ["h1", "h2"] do
        part hole do
          at from: 4
          on [from: 4], set: [color: "var(--success)"]
        end

        part "arg@#{hole}" do
          on [from: 3], set: [color: "var(--success)"]
          on [from: 4], set: [opacity: 0]
        end
      end
    end
  end
end

Examples.MathCopy
