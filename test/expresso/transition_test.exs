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

  # The kind of each slide in the list of the steps of the document.
  defp kinds(deck) do
    deck
    |> Expresso.Test.Steps.read()
    |> Map.fetch!("slides")
    |> Enum.map(& &1["transition"])
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

  test "no element of the document gets a transition attribute" do
    document = MixedDeck |> Expresso.parse() |> Expresso.Deck.render() |> Floki.parse_document!()

    assert document |> Floki.find("[data-transition]") == []
  end

  test "a deck struct takes the kinds from its metadata, and ignores a kind that it does not know" do
    slide = &%Expresso.Slide{name: &1, metadata: &2, elements: []}

    slides = [
      slide.("one", %{}),
      slide.("two", %{transition: :slide}),
      slide.("three", %{transition: :spin})
    ]

    deck =
      "deck" |> Expresso.Deck.new(%{transition: :zoom}, slides) |> Expresso.Deck.number_slides()

    assert kinds(deck) == ["zoom", "slide", "zoom"]
    assert [Expresso.Builder.slide("one")] |> Expresso.Builder.deck() |> kinds() == ["fade"]
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
