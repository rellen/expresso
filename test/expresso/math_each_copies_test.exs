defmodule Expresso.Element.Math.EachCopiesTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.{Math, Part}
  alias Expresso.Element.Math.{Each, Links}

  # g, then a + x + a + x.
  @mathml ~S|<math display="block"><mrow><mi data-part="arg">g</mi><mi>a</mi><mo>+</mo><mi>x</mi><mo>+</mo><mi>a</mi><mo>+</mo><mi>x</mi></mrow></math>|

  defp render(parts) do
    [Builder.slide("a", elements: [Builder.math(@mathml, elements: parts)])]
    |> Builder.deck()
    |> Expresso.Deck.render()
    |> LazyHTML.from_document()
  end

  test "each occurrence of a set gets the class of the set with its number" do
    %Math{text: text} =
      Each.place(%Math{text: @mathml, elements: [%Part{id: "xs", each: "x"}]})

    assert text =~ ~s(<mi class="xs xs-1">x</mi>)
    assert text =~ ~s(<mi class="xs xs-2">x</mi>)
  end

  test "a copy to a set makes one copy for each occurrence" do
    part = Builder.part("arg", copies: [Builder.copy("xs", at: 2)])
    document = render([Builder.part("xs", each: "x"), part])

    copies = LazyHTML.query(document, ".screen .math math.math-copy") |> Enum.to_list()
    assert Enum.flat_map(copies, &LazyHTML.attribute(&1, "data-part")) == ["arg@xs-1", "arg@xs-2"]
    assert Enum.flat_map(copies, &LazyHTML.attribute(&1, "data-copy-of")) == ["arg", "arg"]
    assert Enum.flat_map(copies, &LazyHTML.attribute(&1, "data-move-to")) == ["xs-1", "xs-2"]
  end

  test "a copy of a set to a set pairs the occurrences in order" do
    parts = [
      Builder.part("as", each: "a", copies: [Builder.copy("xs", at: 2)]),
      Builder.part("xs", each: "x")
    ]

    copies =
      render(parts) |> LazyHTML.query(".screen .math math.math-copy") |> Enum.to_list()

    assert Enum.flat_map(copies, &LazyHTML.attribute(&1, "data-copy-of")) == ["as-1", "as-2"]
    assert Enum.flat_map(copies, &LazyHTML.attribute(&1, "data-move-to")) == ["xs-1", "xs-2"]
    assert Enum.map(copies, &(LazyHTML.query(&1, "mi") |> LazyHTML.text())) == ["a", "a"]
  end

  test "sets with a different number of occurrences, and a copy of a copy to a set, stop the render" do
    assert_raise ArgumentError,
                 ~r/"gs" of a math element has 1 occurrences.*needs the same/,
                 fn ->
                   render([
                     Builder.part("gs", each: "g", copies: [Builder.copy("xs", at: 2)]),
                     Builder.part("xs", each: "x")
                   ])
                 end

    assert_raise ArgumentError, ~r/goes to the set "xs", so it cannot have a copy/, fn ->
      render([
        Builder.part("xs", each: "x"),
        Builder.part("arg", copies: [Builder.copy("xs", at: 2, as: "c")]),
        Builder.part("c", copies: [Builder.copy("arg", at: 3)])
      ])
    end
  end

  # Line 1 holds two f, and each \from{fs} of line 2 takes the next one.
  @lines ~S|<math display="block"><mtable><mtr><mtd><mrow data-line="line1"><mi>f</mi><mo>+</mo><mi>f</mi></mrow></mtd></mtr><mtr><mtd><mrow data-line="line2"><mi data-from="fs">f</mi><mi data-from="fs">f</mi></mrow></mtd></mtr></mtable></math>|

  defp lines(text) do
    %Math{
      text: text,
      line_names: ["line1", "line2"],
      elements: [
        %Part{id: "line1"},
        %Part{id: "line2", steps: [2]},
        %Part{id: "fs", each: "f", within: "line1"}
      ]
    }
  end

  test "each link to a set takes the next occurrence of the set in its source line" do
    %Math{text: text, elements: parts} = @lines |> lines() |> Each.place() |> Links.place()
    copies = Enum.filter(parts, & &1.copy_of)

    assert Enum.map(copies, &{&1.id, &1.copy_of, &1.copy_to}) == [
             {"fs-1@link-1", "from-0-fs-1", "link-1"},
             {"fs-2@link-2", "from-0-fs-2", "link-2"}
           ]

    assert text =~ ~s(<mi class="fs fs-1 from-0-fs-1">f</mi>)
    assert text =~ ~s(<mi class="fs fs-2 from-0-fs-2">f</mi>)
  end

  test "more links to a set than occurrences in the source line stop the render" do
    text = String.replace(@lines, ~S|<mi>f</mi><mo>+</mo>|, "")

    assert_raise ArgumentError,
                 ~r/2 links \\from\{fs\} to the line 1, and the set "fs" has 1/,
                 fn ->
                   text |> lines() |> Each.place() |> Links.place()
                 end
  end
end
