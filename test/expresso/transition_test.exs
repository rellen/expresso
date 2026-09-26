defmodule Expresso.TransitionTest do
  use ExUnit.Case, async: true

  # The deck slides, slide two zooms, and slide three has no transition.
  defmodule MixedDeck do
    use Expresso

    name "mixed deck"
    transition :slide

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end

    slide "two" do
      transition :zoom

      text_box do
        text_area(text: "Two")
      end
    end

    slide "three" do
      transition :none

      text_box do
        text_area(text: "Three")
      end
    end
  end

  defmodule PlainDeck do
    use Expresso

    name "plain deck"

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end
  end

  # The value of `data-transition` on each slide of the present view.
  defp kinds(deck) do
    deck
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
    |> Floki.find("section.slide")
    |> Floki.attribute("data-transition")
  end

  test "a deck without the option fades" do
    deck = Expresso.parse(PlainDeck)

    assert deck.metadata.transition == :fade
    assert kinds(deck) == ["fade"]
  end

  test "the option of a slide replaces the option of the deck" do
    deck = Expresso.parse(MixedDeck)

    assert deck.metadata.transition == :slide
    assert Enum.map(deck.slides, & &1.metadata[:transition]) == [nil, :zoom, :none]
    assert kinds(deck) == ["slide", "zoom", "none"]
  end

  test "the handout view gets no transition" do
    document = MixedDeck |> Expresso.parse() |> Expresso.Deck.render() |> Floki.parse_document!()

    assert document |> Floki.find(".handout-page[data-transition]") == []
  end

  test "a deck from the imperative API takes the kinds from its metadata" do
    deck =
      "deck"
      |> Expresso.Deck.new(%{transition: :zoom})
      |> Expresso.Deck.add_slide("one", %{}, [])
      |> Expresso.Deck.add_slide("two", %{transition: :slide}, [])
      |> Expresso.Deck.add_slide("three", %{transition: :spin}, [])

    assert kinds(deck) == ["zoom", "slide", "zoom"]

    assert "deck" |> Expresso.Deck.new() |> Expresso.Deck.add_slide("one", %{}, []) |> kinds() ==
             ["fade"]
  end

  test "the DSL refuses a kind that it does not know" do
    assert_raise Spark.Error.DslError, ~r/transition/, fn ->
      defmodule SpinDeck do
        use Expresso

        transition :spin
      end
    end
  end
end
