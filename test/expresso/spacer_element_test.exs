defmodule Expresso.Element.SpacerTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.Spacer

  defmodule SpacerDeck do
    use Expresso

    name "spacer deck"

    slide "bottom" do
      spacer()

      text_box do
        text_area(text: "At the bottom")
      end
    end

    slide "middle" do
      text_box do
        spacer()
        text_area(text: "In the middle")

        spacer do
          at 2
        end
      end
    end
  end

  defp document(deck), do: deck |> Expresso.parse() |> Expresso.Deck.render()

  test "new/0 makes a spacer" do
    assert Spacer.new() == %Spacer{}
  end

  test "the DSL entity goes at the level of the slide and inside a text box" do
    [bottom, middle] = Expresso.parse(SpacerDeck).slides

    assert [%Spacer{steps: nil}, %{}] = bottom.elements
    assert [%{elements: [%Spacer{}, %{}, %Spacer{steps: [2]}]}] = middle.elements
  end

  test "render/1 writes an empty div with the overlay attributes" do
    document = SpacerDeck |> document() |> Floki.parse_document!()

    assert [{"div", [{"class", "spacer"}], []}] = Floki.find(document, "#slide-1 .spacer")
    assert document |> Floki.find("#slide-2 .spacer") |> Floki.attribute("data-on") == ["2"]
  end
end
