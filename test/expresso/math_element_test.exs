defmodule Expresso.Element.MathTest do
  use ExUnit.Case, async: true

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

  test "new/1 makes a math element" do
    assert Math.new(@formula) == %Math{text: @formula}
  end

  test "the DSL entity takes the MathML as its first argument, with the overlays" do
    [formula, box] = Expresso.parse(MathDeck).slides

    assert [%Math{text: @formula, steps: nil}] = formula.elements
    assert [%{elements: [%Math{steps: nil}]}, %Math{steps: [2, 3]} = second] = box.elements
    assert [%{state: :alert, steps: [3]}] = second.on
  end

  describe "render/1" do
    setup do
      {:ok, document: MathDeck |> document() |> Floki.parse_document!()}
    end

    test "writes the MathML in one block element inside the root tag", %{document: document} do
      [math] = Floki.find(document, "#slide-1 .math")

      assert [{"div", [], [{"math", [{"display", "block"}], _}]}] =
               Floki.find([math], ":root > div")

      assert math |> Floki.find("mfrac mi") |> Enum.map(&Floki.text/1) == ["a", "b"]
    end

    test "writes the overlay attributes on the root tag", %{document: document} do
      [_, second] = Floki.find(document, "#slide-2 .math")

      assert Floki.attribute([second], "data-on") == ["2 3"]
      assert Floki.attribute([second], "data-el") == ["s2-e3"]
    end
  end
end
