defmodule Examples.MathMove do
  use Expresso

  css ".small { font-size: 1rem; }"

  slide "the argument moves into each hole" do
    heading "The argument moves into each hole"

    math do
      class "small"

      line tex: ~S"""
           (\lambda \part{bind}{f}.\,(\lambda x.\part{f1}{f}\,(x\,x))\,
           (\lambda x.\part{f2}{f}\,(x\,x)))\,\part{arg}{g}
           """

      line ~S"\to_\beta",
        tex: ~S"(\lambda x.\part{g1}{g}\,(x\,x))\,(\lambda x.\part{g2}{g}\,(x\,x))",
        why: "f := g",
        name: "reduced"

      part "arg" do
        on [from: 2], set: [color: "var(--success)"]
        on [from: 4], state: :dim
      end

      part "f1" do
        on [from: 2], set: [color: "var(--accent)"]
      end

      part "f2" do
        on [from: 2], set: [color: "var(--accent)"]
      end

      part "reduced", at: [from: 3]

      part "g1" do
        on 3, move_to: "arg"
        on [from: 3], set: [color: "var(--success)"]
      end

      part "g2" do
        on 3, move_to: "arg"
        on [from: 3], set: [color: "var(--success)"]
      end
    end
  end
end

Examples.MathMove
