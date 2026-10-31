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

  test "bare skips the base of a symbol with an index, and keeps a symbol in a group" do
    # x^2 + x_1 + x_1^3 + (x)^2 + x, from Temml.
    mathml =
      ~S|<math><msup><mi>x</mi><mn>2</mn></msup><mo>+</mo><msub><mi>x</mi><mn>1</mn></msub><mo>+</mo><msubsup><mi>x</mi><mn>1</mn><mn>3</mn></msubsup><mo>+</mo><msup><mrow><mo>(</mo><mi>x</mi><mo>)</mo></mrow><mn>2</mn></msup><mo>+</mo><mi>x</mi></math>|

    render = fn part ->
      [Builder.slide("a", elements: [Builder.math(mathml, elements: [part])])]
      |> Builder.deck()
      |> Expresso.Deck.render()
      |> LazyHTML.from_document()
    end

    all = render.(Builder.part("xs", each: "x", on: [Builder.on(2, state: :alert)]))
    assert marked(all, ".xs") == 5

    bare = render.(Builder.part("xs", each: "x", bare: true, on: [Builder.on(2, state: :alert)]))
    assert marked(bare, ".xs") == 2
    assert marked(bare, "msup > mrow > mi.xs") == 1
    assert marked(bare, "math > mi.xs") == 1

    # The index of a symbol is an occurrence of its own text.
    ones =
      render.(Builder.part("ones", each: "1", bare: true, on: [Builder.on(2, state: :alert)]))

    assert marked(ones, ".ones") == 2
  end

  test "the DSL takes each, within and bare inside the block of a part" do
    defmodule BareDeck do
      use Expresso

      slide "math" do
        math ~S|<math><mrow data-part="body"><msub><mi>x</mi><mn>1</mn></msub><mi>x</mi></mrow></math>| do
          part "xs" do
            each "x"
            within "body"
            bare(true)
            on 2, state: :alert
          end
        end
      end
    end

    assert {:ok, deck} = Expresso.to_deck(BareDeck)
    [math] = hd(deck.slides).elements
    assert [%Expresso.Element.Part{each: "x", within: "body", bare: true}] = math.elements
  end

  test "within and bare need each, and a part of a diagram takes none of them" do
    assert_raise ArgumentError, ~r/the part "xs" of a math element has within and no each/, fn ->
      Builder.math(@mathml, elements: [Builder.part("xs", within: "body")])
    end

    assert_raise ArgumentError, ~r/the part "xs" of a math element has bare and no each/, fn ->
      Builder.math(@mathml, elements: [Builder.part("xs", bare: true)])
    end

    assert_raise ArgumentError, ~r/only a part of a formula takes them/, fn ->
      Builder.diagram("test/fixtures/move.svg", elements: [Builder.part("token", each: "x")])
    end

    assert_raise ArgumentError, ~r/has each, within or bare, and only a part/, fn ->
      Builder.diagram("test/fixtures/move.svg", elements: [Builder.part("token", bare: true)])
    end
  end
end
