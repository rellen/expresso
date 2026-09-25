defmodule Expresso.DurationTest do
  use ExUnit.Case, async: true

  defmodule TimedDeck do
    use Expresso

    name "timed deck"
    duration 20

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end
  end

  defmodule UntimedDeck do
    use Expresso

    name "untimed deck"

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end
  end

  defp duration(deck) do
    deck
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
    |> Floki.find("body")
    |> Floki.attribute("data-duration")
  end

  test "the duration option writes the minutes on the body" do
    deck = Expresso.parse(TimedDeck)

    assert deck.metadata.duration == 20
    assert duration(deck) == ["20"]
  end

  test "a deck without the duration option writes no attribute" do
    deck = Expresso.parse(UntimedDeck)

    assert deck.metadata.duration == nil
    assert duration(deck) == []
  end

  test "a deck from the imperative API takes the duration from its metadata" do
    assert duration(Expresso.Deck.new("deck")) == []
    assert duration(Expresso.Deck.new("deck", %{duration: 15})) == ["15"]
    assert duration(Expresso.Deck.new("deck", %{duration: 0})) == []
    assert duration(Expresso.Deck.new("deck", %{duration: "15"})) == []
  end

  test "the DSL refuses a duration that is not a positive integer" do
    assert_raise Spark.Error.DslError, ~r/duration/, fn ->
      defmodule ZeroDeck do
        use Expresso

        duration 0
      end
    end
  end
end
