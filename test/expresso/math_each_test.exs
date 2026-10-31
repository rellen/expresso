defmodule Expresso.Element.Math.EachTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder

  # x^2 + 2x + exp(x), with the part body around 2x + exp(x).
  @mathml ~S|<math><msup><mi>x</mi><mn>2</mn></msup><mo>+</mo><mrow data-part="body"><mn>2</mn><mi>x</mi><mo>+</mo><mi>exp</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow></math>|

  defp document(parts) do
    [Builder.slide("a", elements: [Builder.math(@mathml, elements: parts)])]
    |> Builder.deck()
    |> Expresso.Deck.render()
    |> LazyHTML.from_document()
  end

  defp texts(document, selector),
    do: document |> LazyHTML.query(".screen .math " <> selector) |> Enum.map(&LazyHTML.text/1)

  defp marked(document, selector),
    do: document |> LazyHTML.query(".screen .math " <> selector) |> Enum.count()

  test "a part with each and a new name selects each occurrence in the whole formula" do
    document = document([Builder.part("xs", each: "x", on: [Builder.on(2, state: :alert)])])

    assert texts(document, ".xs") == ["x", "x", "x"]
    assert marked(document, ".xs.math-part[data-el]") == 3
  end

  test "within limits the occurrences to a part, and exp is not an occurrence of x" do
    document =
      document([
        Builder.part("inner", each: "x", within: "body", on: [Builder.on(2, state: :alert)])
      ])

    assert texts(document, ".inner") == ["x", "x"]
    assert texts(document, "mi.inner") == ["x", "x"]
    assert marked(document, "mi:not(.inner)") == 2
  end

  test "the short form puts the options of a part on its occurrences, and not on the part" do
    document = document([Builder.part("body", each: "x", on: [Builder.on(2, state: :alert)])])

    assert texts(document, ".each-body.math-part[data-el]") == ["x", "x"]
    assert marked(document, ~s([data-part="body"][data-el])) == 0
  end

  test "a symbol can be a number or an operator" do
    document = document([Builder.part("plus", each: "+", on: [Builder.on(2, state: :alert)])])
    assert texts(document, ".plus") == ["+", "+"]
  end

  test "a scope that the formula does not have, and a symbol with no occurrence, stop the render" do
    assert_raise ArgumentError, ~r/looks within "nothing", and the formula has no part/, fn ->
      document([Builder.part("xs", each: "x", within: "nothing")])
    end

    assert_raise ArgumentError, ~r/selects each "y", and the formula has none there/, fn ->
      document([Builder.part("ys", each: "y")])
    end
  end

  test "within needs each, and a part of a diagram takes no each" do
    assert_raise ArgumentError, ~r/the part "xs" of a math element has within and no each/, fn ->
      Builder.math(@mathml, elements: [Builder.part("xs", within: "body")])
    end

    assert_raise ArgumentError, ~r/only a part of a formula takes them/, fn ->
      Builder.diagram("test/fixtures/move.svg", elements: [Builder.part("token", each: "x")])
    end
  end
end
