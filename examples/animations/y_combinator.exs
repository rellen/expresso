defmodule Examples.YCombinator do
  use Expresso

  root __DIR__

  # The proof that Y g is equal to g (Y g), with each step of each
  # β-reduction. The script y_combinator/write_svg.exs writes the SVG file.
  # Each symbol is its own text, each copy that moves starts at the place of
  # its source, and each line has a template with the places where the copies
  # land.

  @accent "var(--accent)"
  @argument "var(--success)"

  slide "Y is a fix point" do
    heading "Y is a fix point"

    diagram "y_combinator.svg" do
      width "100%"

      # The lines and their relations.
      part "L0-Y" do
        on 2, set: [color: @accent]
      end

      part "L0" do
        on 13, set: [color: @argument]
      end

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

      part "L1-arg" do
        on 3..6, set: [color: @argument]
        on [from: 7], state: :dim
      end

      part "L1-rest" do
        on [from: 5], state: :dim
      end

      # β-reduction 1: a copy of the body moves down to line 3, and a copy of
      # g moves into each hole.
      part "M1-body" do
        at from: 5
        on [from: 5], move_to: "T2-all"
        on [9, 10, from: 12], state: :dim
        on 11, set: [color: @accent]
      end

      part "M1-f" do
        at 5
        on 5, set: [color: @accent]
      end

      part "M1-bind" do
        on 7..8, set: [color: @accent]
      end

      part "M1-bound" do
        on 8, set: [color: @accent]
      end

      part "M1-arg" do
        on 7..8, set: [color: @argument]
      end

      part "M1-g1" do
        at from: 6
        on [from: 6], move_to: "T2-c4"
        on 6, set: [color: @argument]
        on [9, 10, from: 12], state: :dim
        on 11, set: [color: @accent]
      end

      part "M1-g2" do
        at from: 6
        on [from: 6], move_to: "T2-c17"
        on 6..8, set: [color: @argument]
        on [9, 10, from: 12], state: :dim
        on 11, set: [color: @accent]
      end

      part "rel2", at: [from: 6]
      part "why2", at: [from: 6]

      # β-reduction 2: copies of the body move down to line 4, and a copy of
      # the argument moves into each hole.
      part "M2-g" do
        at from: 9
        on [from: 9], move_to: "T3-c0"
      end

      part "M2-lp" do
        at from: 9
        on [from: 9], move_to: "T3-c2"
      end

      part "M2-rp" do
        at from: 9
        on [from: 9], move_to: "T3-c28"
      end

      part "M2-x1" do
        at 9
        on 9, move_to: "T3-s1", set: [color: @accent]
      end

      part "M2-x2" do
        at 9
        on 9, move_to: "T3-s2", set: [color: @accent]
      end

      part "M2-a1" do
        at from: 10
        on [from: 10], move_to: "T3-s1"
        on 10, set: [color: @argument]
        on 11..12, set: [color: @accent]
      end

      part "M2-a2" do
        at from: 10
        on [from: 10], move_to: "T3-s2"
        on 10, set: [color: @argument]
        on 11..12, set: [color: @accent]
      end

      part "rel3", at: [from: 10]
      part "why3", at: [from: 10]

      # The last line: g ( … ) with Y g from line 1 inside.
      part "M3-g" do
        at from: 12
        on [from: 12], move_to: "T4-c0"
        on 13, set: [color: @argument]
      end

      part "M3-lp" do
        at from: 12
        on [from: 12], move_to: "T4-c2"
        on 13, set: [color: @argument]
      end

      part "M3-rp" do
        at from: 12
        on [from: 12], move_to: "T4-c6"
        on 13, set: [color: @argument]
      end

      part "M3-Yg" do
        at from: 12
        on [from: 12], move_to: "T4-s"
        on 12, set: [color: @accent]
        on 13, set: [color: @argument]
      end

      part "rel4", at: [from: 12]
      part "why4", at: [from: 12]

      # One caption at each step.
      part "cap1", at: 1
      part "cap2", at: 2
      part "cap3", at: 3
      part "cap4", at: 4
      part "cap5", at: 5
      part "cap6", at: 6
      part "cap7", at: 7
      part "cap8", at: 8
      part "cap9", at: 9
      part "cap10", at: 10
      part "cap11", at: 11
      part "cap12", at: 12
      part "cap13", at: 13
    end
  end
end

Examples.YCombinator
