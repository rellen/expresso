defmodule Expresso.MorphTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder

  defp document(slides, opts \\ []) do
    slides
    |> Builder.deck(Keyword.merge([name: "morph"], opts))
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
  end

  defp modes(document) do
    document
    |> Floki.find(".screen section.slide")
    |> Enum.flat_map(&Floki.attribute(&1, "data-morph"))
  end

  test "each slide has the morph of the deck, :auto by default, and a slide replaces it" do
    slides = [Builder.slide("a"), Builder.slide("b", morph: :off), Builder.slide("c")]

    assert modes(document(slides)) == ["auto", "off", "auto"]
    assert modes(document(slides, morph: :named)) == ["named", "off", "named"]
  end

  test "the morph option of an element gives its key, on each kind" do
    document =
      document([
        Builder.slide("a",
          elements: [
            Builder.text_area(text: "Expresso", morph: "brand"),
            Builder.stat(3, morph: "count"),
            Builder.text_area(text: "No key")
          ]
        )
      ])

    keys =
      document
      |> Floki.find(".screen [data-morph-key]")
      |> Enum.flat_map(&Floki.attribute(&1, "data-morph-key"))

    assert keys == ["brand", "count"]
  end

  test "a code element names its language, so the morph can compare two codes" do
    document = document([Builder.slide("a", elements: [Builder.code("elixir", text: "x = 1")])])

    assert document |> Floki.find(".screen .code") |> Floki.attribute("data-language") == [
             "elixir"
           ]
  end

  test "the compiler refuses a mode that is not :auto, :named or :off" do
    assert_raise ArgumentError, ~r/morph/, fn -> Builder.slide("a", morph: :fade) end
    assert_raise ArgumentError, ~r/morph/, fn -> Builder.deck([], name: "x", morph: true) end
  end

  test "the DSL takes the morph of the deck, of a slide and of an element" do
    defmodule Deck do
      use Expresso

      morph :named

      slide "a" do
        text_area(text: "Expresso", morph: "brand")
      end

      slide "b" do
        morph :auto

        text_area do
          text "Expresso"
          morph "brand"
        end
      end
    end

    assert {:ok, deck} = Expresso.to_deck(Deck)
    document = deck |> Expresso.Deck.render() |> Floki.parse_document!()
    assert modes(document) == ["named", "auto"]
    assert length(Floki.find(document, ~s(.screen [data-morph-key="brand"]))) == 2
  end
end
