defmodule Expresso.Element.MathTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Math

  @formula ~S(<math display="block"><mfrac><mi>a</mi><mi>b</mi></mfrac></math>)

  defmodule MathDeck do
    use Expresso

    name "math deck"

    slide "formula" do
      math ~S(<math display="block"><mfrac><mi>a</mi><mi>b</mi></mfrac></math>)
    end

    slide "in a box" do
      auto_reveal true

      text_box do
        math ~S(<math><mi>x</mi></math>)
      end

      math ~S(<math><mi>y</mi></math>) do
        on :next, state: :alert
      end
    end
  end

  defp document(deck), do: deck |> Expresso.parse() |> Expresso.Deck.render()

  test "Expresso.Builder.math/1 makes a math element" do
    assert %Math{text: @formula} = Builder.math(@formula)
  end

  test "the DSL entity takes the MathML as its first argument, with the overlays" do
    [formula, box] = Expresso.parse(MathDeck).slides

    assert [%Math{text: @formula, steps: nil}] = formula.elements
    assert [%{elements: [%Math{steps: nil}]}, %Math{steps: [2, 3]} = second] = box.elements
    assert [%{state: :alert, steps: [3]}] = second.on
  end

  describe "render/1" do
    setup do
      {:ok, document: MathDeck |> document() |> LazyHTML.from_document()}
    end

    test "writes the MathML in one block element inside the root tag", %{document: document} do
      assert count(document, "#slide-1 .math") == 1

      assert [{"div", [], [{"math", [{"display", "block"}], _}]}] =
               document |> LazyHTML.query("#slide-1 .math > div") |> LazyHTML.to_tree()

      assert texts(document, "#slide-1 .math mfrac mi") == ["a", "b"]
    end

    test "writes the overlay attributes on the root tag", %{document: document} do
      [_, second] = document |> LazyHTML.query("#slide-2 .math") |> Enum.to_list()

      assert LazyHTML.attribute(second, "data-on") == ["2 3"]
      assert LazyHTML.attribute(second, "data-el") == ["s2-e3"]
    end
  end
end
