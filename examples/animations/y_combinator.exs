defmodule Examples.YCombinator do
  use Expresso

  root __DIR__

  # The proof that Y g is equal to g (Y g), with each step of each
  # β-reduction. The script y_combinator/write_svg.exs writes the SVG file.
  # Each symbol is its own text, and the file holds each line one time. A copy
  # of a symbol or of a term moves from one line to its place in the next
  # line. When the copies of a line land, the line shows and the copies fade.

  @accent "var(--accent)"
  @argument "var(--success)"

  slide "Y is a fix point" do
    heading "Y is a fix point"

    diagram "y_combinator.svg" do
      width "100%"

      # Line 0, and a copy of Y g into g ( … ) of line 4 at step 12.
      part "L0-Y" do
        on 2, set: [color: @accent]
      end

      part "L0" do
        on 13, set: [color: @argument]

        copy "L4-s" do
          at from: 12
          on 12, set: [color: @accent]
          on [from: 13], set: [opacity: 0]
        end
      end

      # Line 1: the definition of Y applied to g.
      part "L1", at: [from: 2]
      part "rel1", at: [from: 2]
      part "why1", at: [from: 2]

      part "L1-def" do
        on 2, set: [color: @accent]
      end

      part "L1-bind" do
        on 3..6, set: [color: @accent]
        on [from: 7], state: :dim
      end

      part "L1-bound" do
        on 4..6, set: [color: @accent]
        on [from: 7], state: :dim
      end

      for rest <- ["L1-head", "L1-body-rest", "L1-close"] do
        part rest do
          on [from: 5], state: :dim
        end
      end

      # β-reduction 1: a copy of the body moves down to line 2, and a copy of
      # g moves into the place of each f.
      part "L1-body" do
        copy "L2" do
          at from: 5
          on [from: 7], set: [opacity: 0]
        end
      end

      part "L1-body@L2-L1-bound" do
        on 5, set: [color: @accent]
        on [from: 6], set: [opacity: 0]
      end

      part "L1-arg" do
        on 3..6, set: [color: @argument]
        on [from: 7], state: :dim

        for hole <- ["L2-c4", "L2-c17"] do
          copy hole do
            at from: 6
            on 6, set: [color: @argument]
            on [from: 7], set: [opacity: 0]
          end
        end
      end

      # Line 2.
      part "L2" do
        at from: 7
        on [9, 10, from: 12], state: :dim
        on 11, set: [color: @accent]
      end

      part "rel2", at: [from: 6]
      part "why2", at: [from: 6]

      part "L2-bind" do
        on 7..8, set: [color: @accent]
      end

      part "L2-bound" do
        on 8, set: [color: @accent]
      end

      # β-reduction 2: copies of the symbols of the body move down to line 3,
      # the two x make room, and a copy of the argument moves into the place
      # of each x.
      for {source, target} <- [{"L2-c4", "L3-c0"}, {"L2-c6", "L3-c2"}, {"L2-c10", "L3-c28"}] do
        part source do
          copy target do
            at from: 9
            on [from: 11], set: [opacity: 0]
          end
        end
      end

      for {source, target} <- [{"L2-c7", "L3-s1"}, {"L2-c9", "L3-s2"}] do
        part source do
          copy target do
            at from: 9
            on 9, set: [color: @accent]
            on [from: 10], set: [opacity: 0]
          end
        end
      end

      part "L2-arg" do
        on 7..8, set: [color: @argument]

        for hole <- ["L3-s1", "L3-s2"] do
          copy hole do
            at from: 10
            on 10, set: [color: @argument]
            on [from: 11], set: [opacity: 0]
          end
        end
      end

      # Line 3.
      part "L3", at: [from: 11]
      part "rel3", at: [from: 10]
      part "why3", at: [from: 10]

      for inner <- ["L3-s1", "L3-s2"] do
        part inner do
          on 11..12, set: [color: @accent]
        end
      end

      # The last line: copies of g, ( and ) of line 3, and the copy of Y g
      # from line 0.
      for {source, target} <- [{"L3-c0", "L4-c0"}, {"L3-c2", "L4-c2"}, {"L3-c28", "L4-c6"}] do
        part source do
          copy target do
            at from: 12
            on [from: 13], set: [opacity: 0]
          end
        end
      end

      part "L4" do
        at from: 13
        on 13, set: [color: @argument]
      end

      part "rel4", at: [from: 12]
      part "why4", at: [from: 12]

      # One caption at each step.
      for step <- 1..13 do
        part "cap#{step}", at: step
      end
    end
  end
end

Examples.YCombinator
