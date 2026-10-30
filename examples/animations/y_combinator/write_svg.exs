# Writes ../y_combinator.svg for the deck y_combinator.exs. Each symbol of each
# term is its own text, so that a part of the diagram can color, dim or copy
# it. Run it after a change to a term:
#
#     elixir examples/animations/y_combinator/write_svg.exs
#
# The file holds each line of the proof one time. The deck copies the symbols
# of a line to their places in the next line, so the file holds no copy. Each
# symbol of a line has the id "L<line>-c<index>", and a copy can land on it.
#
# Each symbol has a cell of one width, because the script cannot measure the
# glyphs of the font.

defmodule Examples.YCombinator.Svg do
  @moduledoc false

  @size 30
  @glyph 19
  @space 10
  @left 130

  # The center of the cell of each symbol of a term.
  defp cells(term) do
    term
    |> String.graphemes()
    |> Enum.map_reduce(@left, fn char, x ->
      width = if char == " ", do: @space, else: @glyph
      {{char, x + width / 2}, x + width}
    end)
    |> elem(0)
  end

  def y(line), do: 70 + line * 72

  # One text for each symbol at `indexes` of the term of the line `line`. Each
  # symbol gets the id "L<line>-c<index>".
  def symbols(term, indexes, line) do
    cells = cells(term)

    for i <- indexes, {char, x} <- [Enum.at(cells, i)], char != " " do
      ~s(<text id="L#{line}-c#{i}" x="#{x}" y="#{y(line)}" text-anchor="middle" ) <>
        ~s(font-size="#{@size}" fill="currentColor"#{style(char)}>#{char}</text>)
    end
  end

  defp style(char) when char in ["(", ")", ".", "λ"], do: ""
  defp style(_char), do: ~s( font-style="italic")

  def group(id, children), do: [~s(<g id="#{id}">), children, "</g>"]

  def note(id, x, line, text, anchor \\ "start", size \\ 22) do
    ~s(<text id="#{id}" x="#{x}" y="#{y(line)}" text-anchor="#{anchor}" font-size="#{size}" ) <>
      ~s(fill="currentColor">#{text}</text>)
  end
end

defmodule Examples.YCombinator.Svg.Write do
  @moduledoc false

  import Examples.YCombinator.Svg

  @l0 "Y g"
  @l1 "(λf.(λx.f (x x)) (λx.f (x x))) g"
  @l2 "(λx.g (x x)) (λx.g (x x))"
  @l3 "g ((λx.g (x x)) (λx.g (x x)))"
  @l4 "g (Y g)"

  @captions [
    "The claim: Y g is a fix point of g.",
    "Unfold Y: replace Y with its definition.",
    "β-reduction 1. The redex: λf. … applied to the argument g.",
    "λf binds each f in the body.",
    "Copy the body down.",
    "Put the argument g in the place of each f.",
    "β-reduction 2. The redex: λx.g (x x) applied to a copy of itself.",
    "λx binds each x in the body.",
    "Copy the body down, and make room for the argument.",
    "Put the argument in the place of each x.",
    "The term inside g ( … ) is line 3, and Y g reduces to line 3.",
    "So the term is equal to Y g.",
    "Y g =β g (Y g): Y g is a fix point of g."
  ]

  def run(path) do
    # The body of the first β-reduction is line 2 with f in the place of g.
    @l2 = @l1 |> String.slice(4..28) |> String.replace("f", "g")

    svg = [
      ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1180 480" width="1180" ),
      ~s(height="480" font-family="'Latin Modern Math', 'STIX Two Math', 'Cambria Math', serif">),
      "<title>The proof that Y g is a fix point of g</title>",

      # Line 0: Y g.
      group("L0", [group("L0-Y", symbols(@l0, [0], 0)), symbols(@l0, [2], 0)]),

      # Line 1: the definition of Y applied to g. The body of the λf is the
      # source of the copy of the first β-reduction.
      group("L1", [
        group("L1-def", [
          group("L1-head", symbols(@l1, [0, 3], 1)),
          group("L1-bind", symbols(@l1, [1, 2], 1)),
          group("L1-body", [
            group("L1-bound", symbols(@l1, [8, 21], 1)),
            group("L1-body-rest", symbols(@l1, Enum.to_list(4..28) -- [8, 21], 1))
          ]),
          group("L1-close", symbols(@l1, [29], 1))
        ]),
        group("L1-arg", symbols(@l1, [31], 1))
      ]),

      # Line 2: the result of the first β-reduction.
      group("L2", [
        group("L2-bind", symbols(@l2, [1, 2], 2)),
        group("L2-bound", symbols(@l2, [7, 9], 2)),
        group("L2-arg", symbols(@l2, 13..24, 2)),
        symbols(@l2, [0, 3, 4, 5, 6, 8, 10, 11, 12], 2)
      ]),

      # Line 3: the result of the second β-reduction. Each argument is in the
      # place of an x.
      group("L3", [
        symbols(@l3, [0, 2, 28], 3),
        group("L3-s1", symbols(@l3, 3..14, 3)),
        group("L3-s2", symbols(@l3, 16..27, 3))
      ]),

      # Line 4: g (Y g).
      group("L4", [symbols(@l4, [0, 2, 6], 4), group("L4-s", symbols(@l4, 3..5, 4))]),

      # The relations, the reasons and the captions.
      note("rel1", 70, 1, "=", "middle", 30),
      note("rel2", 70, 2, "→β", "middle", 30),
      note("rel3", 70, 3, "→β", "middle", 30),
      note("rel4", 70, 4, "=β", "middle", 30),
      note("why1", 820, 1, "the definition of Y"),
      note("why2", 820, 2, "f := g"),
      note("why3", 820, 3, "x := λx.g (x x)"),
      note("why4", 820, 4, "line 3 =β Y g"),
      for {text, n} <- Enum.with_index(@captions, 1) do
        note("cap#{n}", 590, 5.6, text, "middle", 24)
      end,
      "</svg>\n"
    ]

    File.write!(path, svg)
  end
end

Examples.YCombinator.Svg.Write.run(Path.join(__DIR__, "../y_combinator.svg"))
