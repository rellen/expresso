defmodule Examples.MathLink do
  use Expresso

  css ".small { font-size: 1.25rem; }"

  slide "build the next line" do
    heading "Build the next line"

    math do
      class "small"
      reveal true

      line tex:
             ~S"(\lambda \part{bind}{f}.\,\part{f1}{f}\,\part{open}{(}\part{f2}{f}\,\part{x}{x)})\,\part{arg}{g}"

      line ~S"\to_\beta",
        tex: ~S"\from{arg}{\part{g1}{g}}\,\from{open}{(}\from{arg}{\part{g2}{g}}\,\from{x}{x)}",
        why: "f := g",
        steps: 2

      for bound <- ["bind", "f1", "f2"] do
        part bound do
          on [from: 1], set: [color: "var(--accent)"]
        end
      end

      for argument <- ["arg", "g1", "g2"] do
        part argument do
          on [from: 1], set: [color: "var(--success)"]
        end
      end
    end
  end
end

Examples.MathLink
