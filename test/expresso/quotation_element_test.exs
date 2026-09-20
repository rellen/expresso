defmodule Expresso.Element.QuotationTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.Quotation

  defmodule QuotationDeck do
    use Expresso

    name "quotation deck"

    slide "with a source" do
      quotation "Less is <b>more</b>." do
        by "Ludwig Mies van der Rohe"
      end
    end

    slide "without a source" do
      auto_reveal true

      text_box do
        quotation "A short one."
      end

      quotation "A second one." do
        on :next, state: :alert
      end
    end
  end

  defp document(deck), do: deck |> Expresso.parse() |> Expresso.Deck.render()

  describe "new/2" do
    test "makes a quotation with text and a source" do
      assert Quotation.new("a") == %Quotation{text: "a", by: nil}
      assert Quotation.new("a", "b").by == "b"
    end
  end

  describe "the DSL entity" do
    test "takes the text as its first argument and the by option" do
      [slide, _] = Expresso.parse(QuotationDeck).slides

      assert [%Quotation{text: "Less is <b>more</b>.", by: "Ludwig Mies van der Rohe"}] =
               slide.elements
    end

    test "goes at the level of the slide and inside a text box, with the overlays" do
      [_, slide] = Expresso.parse(QuotationDeck).slides

      assert [%{elements: [%Quotation{by: nil, steps: nil}]}, %Quotation{steps: [2, 3]} = second] =
               slide.elements

      assert [%{state: :alert, steps: [3]}] = second.on
    end
  end

  describe "render/1" do
    setup do
      {:ok, document: QuotationDeck |> document() |> Floki.parse_document!()}
    end

    test "writes a figure with a blockquote, and the text in one block element", %{
      document: document
    } do
      [figure] = Floki.find(document, "#slide-1 figure.quotation")

      assert [{"div", [], _}] = Floki.find([figure], "blockquote > div")
      assert figure |> Floki.find("blockquote b") |> Floki.text() == "more"
    end

    test "writes the source in a figcaption element", %{document: document} do
      assert document |> Floki.find("#slide-1 figcaption") |> Floki.text() ==
               "Ludwig Mies van der Rohe"
    end

    test "writes no figcaption without the by option", %{document: document} do
      assert [] = Floki.find(document, "#slide-2 figcaption")
    end

    test "writes the overlay attributes on the figure", %{document: document} do
      [_, second] = Floki.find(document, "#slide-2 figure.quotation")

      assert Floki.attribute([second], "data-on") == ["2 3"]
      assert Floki.attribute([second], "data-el") == ["s2-e3"]
    end
  end
end
