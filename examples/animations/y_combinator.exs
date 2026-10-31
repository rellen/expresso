defmodule Examples.YCombinator do
  use Expresso

  # The proof that Y g is equal to g (Y g), with each step of each
  # β-reduction. Each line comes from the lines before it: \from marks a
  # sub-term that comes from a part of an earlier line, and a copy of that
  # part moves to its place at the step of the line. The body of each λ is in
  # parts around its holes, so a copy of the argument lands in an empty place.

  @accent "var(--accent)"
  @argument "var(--success)"

  css ".small { font-size: 1rem; }"

  slide "Y is a fix point" do
    heading "Y is a fix point"

    math do
      class "small"

      line tex: ~S"\part{Yg}{\part{Y}{Y}\,g}"

      line "=",
        tex: ~S"""
        \part{def}{(\lambda \part{bind}{f}.\,\part{lam1}{(\lambda x.}\,\part{f1}{f}\,
        \part{app1}{(x\,x))}\,\part{lam2}{(\lambda x.}\,\part{f2}{f}\,
        \part{app2}{(x\,x))})}\,\part{arg}{g}
        """,
        why: "the definition of Y"

      line ~S"\to_\beta",
        tex: ~S"""
        \from{lam1}{(\lambda \part{bindx}{x}.}\,\from{arg}{\part{g2}{g}}\,
        \from{app1}{\part{bound}{(x\,x))}}\,
        \part{A}{\from{lam2}{(\lambda x.}\,\from{arg}{g}\,\from{app2}{(x\,x))}}
        """,
        why: "f := g"

      line ~S"\to_\beta",
        tex: ~S"""
        \from{g2}{\part{g3}{g}}\,(\from{A}{(\lambda x.\,g\,(x\,x))}\,
        \from{A}{(\lambda x.\,g\,(x\,x))})
        """,
        why: ~S"x := λx.g (x x)"

      line ~S"=_\beta",
        tex: ~S"\from{g3}{\part{g4}{g}}\,(\from{Yg}{\part{Yg4}{Y\,g}})",
        why: "line 3 =β Y g"

      # Line 1 shows at step 2, line 2 at step 5, line 3 at step 8 and line 4
      # at step 9. An old line dims after the step that uses it.
      part "line2" do
        at from: 2
        on [from: 6], state: :dim
      end

      part "line3" do
        at from: 5
        on [from: 9], state: :dim
      end

      part "line4", at: [from: 8]
      part "line5", at: [from: 9]

      part "Y" do
        on 2, set: [color: @accent]
      end

      part "def" do
        on 2, set: [color: @accent]
      end

      part "bind" do
        on 3..4, set: [color: @accent]
      end

      for bound <- ["f1", "f2"] do
        part bound do
          on 4, set: [color: @accent]
        end
      end

      part "arg" do
        on 3..5, set: [color: @argument]
      end

      # The second β-reduction: λx.g (x x) applied to a copy of itself.
      part "bindx" do
        on 6..7, set: [color: @accent]
      end

      part "bound" do
        on 7, set: [color: @accent]
      end

      part "A" do
        on 6..8, set: [color: @argument]
      end

      # Y g and the copy of Y g in the last line, and the g in front of it.
      for last <- ["Yg", "g4", "Yg4"] do
        part last do
          on [from: 9], set: [color: @argument]
        end
      end
    end
  end
end

Examples.YCombinator
