# Writes ../y_combinator.svg for the deck y_combinator.exs. Each symbol of each
# term is its own text, so that a part of the diagram can color, dim or move
# it. Run it after a change to a term:
#
#     elixir examples/animations/y_combinator/write_svg.exs
#
# Each symbol has a cell of one width, because the script cannot measure the
# glyphs of the font. Issue #472 asks for a math element that lays out the
# terms and gives a name to each part.

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

  # One text for each symbol at `indexes` of `term`, on the line `line`. A copy
  # that moves starts at the line of its source. A symbol with `name` gets the
  # id "<name>-c<index>", so that `move_to` can name it.
  def symbols(term, indexes, line, name \\ nil) do
    cells = cells(term)

    for i <- indexes, {char, x} <- [Enum.at(cells, i)], char != " " do
      id = if name, do: ~s( id="#{name}-c#{i}"), else: ""

      ~s(<text#{id} x="#{x}" y="#{y(line)}" text-anchor="middle" font-size="#{@size}" ) <>
        ~s(fill="currentColor"#{style(char)}>#{char}</text>)
    end
  end

  defp style(char) when char in ["(", ")", ".", "λ"], do: ""
  defp style(_char), do: ~s( font-style="italic")

  def group(id, children), do: [~s(<g id="#{id}">), children, "</g>"]

  # A template: the places where the copies land. It does not show.
  def template(id, children), do: [~s(<g id="#{id}" opacity="0">), children, "</g>"]

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

  # The places in @l2 of the parts of the second β-reduction. The body of the
  # first β-reduction is @l1 from 4 to 28, so a copy of the body starts at a
  # place in @l2 plus 4, on line 1.
  @l2_bind [1, 2]
  @l2_bound [7, 9]
  @l2_g [4, 17]
  @l2_arg Enum.to_list(13..24) -- [17]
  @l2_rest Enum.to_list(0..24) -- (@l2_bind ++ @l2_bound ++ @l2_g ++ @l2_arg)

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
    # The body of the first β-reduction is @l2 with f in the place of g.
    @l2 = @l1 |> String.slice(4..28) |> String.replace("f", "g")

    from_body = fn places -> Enum.map(places, &(&1 + 4)) end

    svg = [
      ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1180 480" width="1180" ),
      ~s(height="480" font-family="'Latin Modern Math', 'STIX Two Math', 'Cambria Math', serif">),
      "<title>The proof that Y g is a fix point of g</title>",

      # The first two lines.
      group("L0", [group("L0-Y", symbols(@l0, [0], 0)), symbols(@l0, [2], 0)]),
      group("L1", [
        group("L1-def", [
          group("L1-bind", symbols(@l1, [1, 2], 1)),
          group("L1-bound", symbols(@l1, [8, 21], 1)),
          group("L1-rest", symbols(@l1, Enum.to_list(0..29) -- [1, 2, 8, 21], 1))
        ]),
        group("L1-arg", symbols(@l1, [31], 1))
      ]),

      # The templates of lines 2, 3 and 4.
      template("T2", group("T2-all", symbols(@l2, 0..24, 2, "T2"))),
      template("T3", [
        symbols(@l3, [0, 2, 28], 3, "T3"),
        group("T3-s1", symbols(@l3, 3..14, 3)),
        group("T3-s2", symbols(@l3, 16..27, 3))
      ]),
      template("T4", [symbols(@l4, [0, 2, 6], 4, "T4"), group("T4-s", symbols(@l4, 3..5, 4))]),

      # β-reduction 1: a copy of the body of line 1, and two copies of g.
      group("M1-body", [
        group("M1-f", symbols(@l1, from_body.(@l2_g), 1)),
        group("M1-bind", symbols(@l1, from_body.(@l2_bind), 1)),
        group("M1-bound", symbols(@l1, from_body.(@l2_bound), 1)),
        group("M1-arg", symbols(@l1, from_body.(@l2_arg), 1)),
        group("M1-rest", symbols(@l1, from_body.(@l2_rest), 1))
      ]),
      group("M1-g1", symbols(@l1, [31], 1)),
      group("M1-g2", symbols(@l1, [31], 1)),

      # β-reduction 2: copies of the symbols of line 2.
      group("M2-g", symbols(@l2, [4], 2)),
      group("M2-lp", symbols(@l2, [6], 2)),
      group("M2-x1", symbols(@l2, [7], 2)),
      group("M2-x2", symbols(@l2, [9], 2)),
      group("M2-rp", symbols(@l2, [10], 2)),
      group("M2-a1", symbols(@l2, 13..24, 2)),
      group("M2-a2", symbols(@l2, 13..24, 2)),

      # The last line: copies of g, ( and ) of line 3, and a copy of Y g.
      group("M3-g", symbols(@l3, [0], 3)),
      group("M3-lp", symbols(@l3, [2], 3)),
      group("M3-rp", symbols(@l3, [28], 3)),
      group("M3-Yg", symbols(@l0, 0..2, 0)),

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
