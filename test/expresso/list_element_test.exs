defmodule Expresso.Element.ListTest do
  use ExUnit.Case, async: true

  import Spark.Test, only: [dsl_errors: 1]

  alias Expresso.Element.Item
  alias Expresso.Overlay

  defmodule ListDeck do
    use Expresso

    name "list deck"

    slide "plain" do
      list do
        item "First"

        item "Second" do
          list do
            ordered true
            item "Nested <b>one</b>"

            item "Nested two" do
              list do
                item "Third level"
              end
            end
          end
        end
      end
    end

    slide "reveal" do
      list do
        reveal true
        item "One"
        item "Two"
        item "Three"
      end

      text_box do
        at :next
        text_area(text: "After the list")
      end
    end

    slide "reveal at" do
      list do
        at from: 3
        reveal true
        item "One"
        item "Two"
      end

      text_box do
        at :next
        text_area(text: "The counter did not move")
      end
    end

    slide "reveal and at" do
      list do
        reveal true
        item "One"

        item "Two" do
          at from: 1
          on 2, state: :alert
        end
      end
    end

    slide "auto" do
      auto_reveal true

      list do
        reveal true
        item "One"
        item "Two"
      end

      text_box do
        text_area(text: "After the list")
      end
    end
  end

  defp slide(name) do
    Enum.find(Expresso.parse(ListDeck).slides, &(&1.name == name))
  end

  defp document(deck), do: deck |> Expresso.parse() |> Expresso.Deck.render()

  describe "new/2" do
    test "makes a list from items" do
      list = Expresso.Element.List.new([Item.new("a"), Item.new("b", [])], ordered: true)

      assert [%Item{text: "a"}, %Item{text: "b"}] = list.elements
      assert list.ordered == true
      assert list.reveal == false
    end
  end

  describe "the DSL entity" do
    test "holds items, and an item holds text and one nested list" do
      [list] = slide("plain").elements

      assert [%Item{text: "First", elements: []}, %Item{text: "Second"} = second] = list.elements
      assert [%Expresso.Element.List{ordered: true} = nested] = second.elements
      assert [%Item{text: "Nested <b>one</b>"}, %Item{elements: [third]}] = nested.elements
      assert [%Item{text: "Third level"}] = third.elements
    end

    test "shows each item at each step without the reveal option" do
      [list] = slide("plain").elements

      assert list.steps == nil
      assert Enum.map(list.elements, & &1.steps) == [nil, nil]
    end

    test "reveals one item at each step with the reveal option" do
      [list, box] = slide("reveal").elements

      assert list.reveal == true
      assert Enum.map(list.elements, & &1.steps) == [[1, 2, 3, 4], [2, 3, 4], [3, 4]]
      assert box.steps == [4]
      assert slide("reveal").metadata.max_step == 4
    end

    test "starts the items at the first step of a list with an absolute at option" do
      [list, box] = slide("reveal at").elements

      assert list.steps == [3, 4]
      assert Enum.map(list.elements, & &1.steps) == [[3, 4], [4]]
      assert box.steps == [1]
      assert slide("reveal at").metadata.max_step == 4
    end

    test "reports an item outside a list with a closed at option" do
      errors =
        dsl_errors do
          defmodule Elixir.Expresso.Element.ListTest.ClosedList do
            use Expresso

            slide do
              list do
                at 3
                reveal true
                item "One"
                item "Two"
              end
            end
          end
        end

      assert [{Expresso.Element.ListTest.ClosedList, [error]}] = errors
      assert Exception.message(error) =~ "the item has the step 4, and the list does not show"
    end

    test "keeps the at option and the on entity of an item" do
      [list] = slide("reveal and at").elements
      [one, two] = list.elements

      assert one.steps == [1, 2]
      assert %Item{at: %Overlay{pairs: [{1, :max}]}, steps: [1, 2]} = two
      assert [%{state: :alert, steps: [2]}] = two.on
    end

    test "continues the counter of auto_reveal" do
      [list, box] = slide("auto").elements

      assert list.steps == [1, 2, 3, 4]
      assert Enum.map(list.elements, & &1.steps) == [[2, 3, 4], [3, 4]]
      assert box.steps == [4]
    end
  end

  describe "render/1" do
    setup do
      {:ok, document: ListDeck |> document() |> Floki.parse_document!()}
    end

    test "writes a ul element with one li for each item", %{document: document} do
      [list] = Floki.find(document, "#slide-1 .slide-main > ul.list")

      assert [_, _] = Floki.find([list], ":root > li.item")
    end

    test "writes an ordered list as an ol element", %{document: document} do
      assert [_] = Floki.find(document, "#slide-1 li.item > ol.list")
      assert [_] = Floki.find(document, "#slide-1 ol.list li.item ul.list li.item")
    end

    test "writes the text of an item in one block element, with raw HTML", %{document: document} do
      [item] = Floki.find(document, "#slide-1 ol.list > li.item:first-child")

      assert [{"div", [], _}] = Floki.find([item], ":root > div")
      assert item |> Floki.find("b") |> Floki.text() == "one"
    end

    test "writes the overlay attributes on the list and on each item", %{document: document} do
      [list] = Floki.find(document, "#slide-2 ul.list")

      assert Floki.attribute([list], "data-on") == []

      assert [list] |> Floki.find("li.item") |> Floki.attribute("data-on") == [
               "1 2 3 4",
               "2 3 4",
               "3 4"
             ]

      [two] = Floki.find(document, "#slide-4 li.item:last-child")
      assert Floki.attribute([two], "data-el") == ["s4-e3"]
    end
  end
end
