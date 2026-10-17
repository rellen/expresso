defmodule Expresso.Test.DecksTest do
  use ExUnit.Case, async: true

  import Expresso.Test.Decks

  alias Expresso.Builder
  alias Expresso.Element.{TextArea, TextBox}
  alias Expresso.Test.Warnings

  defmodule Deck do
    use Expresso

    name "decks"

    slide "first" do
      text_box do
        text_area(text: "a")
      end
    end

    slide "second" do
      text_box do
        text_area(text: "b")
      end
    end
  end

  test "find_slide finds a slide by its name, in a deck and in the deck of a DSL module" do
    assert %{name: "second"} = find_slide(Deck, "second")
    assert find_slide(Expresso.parse(Deck), "second") == find_slide(Deck, "second")
    assert find_slide(Builder.deck([Builder.slide("one")]), "one").name == "one"
    assert find_slide(Deck, "third") == nil
  end

  test "box makes a text box with one text area" do
    assert %TextBox{elements: [%TextArea{text: "a"}]} = box("a")
  end

  test "Warnings.texts gives the text of each warning, with or without its annotation" do
    assert Warnings.texts(["a", {"b", [line: 3]}]) == ["a", "b"]
  end
end
