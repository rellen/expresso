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

  # The length of the talk in the list of the steps of the document.
  defp duration(deck), do: Expresso.Test.Steps.read(deck)["duration_ms"]

  test "the duration option writes the length in milliseconds into the document" do
    deck = Expresso.parse(TimedDeck)

    assert deck.metadata.duration == 20
    assert duration(deck) == 1_200_000
  end

  test "a deck without the duration option writes null" do
    deck = Expresso.parse(UntimedDeck)

    assert deck.metadata.duration == nil
    assert duration(deck) == nil
  end

  test "a deck struct takes the duration from its metadata" do
    assert duration(Expresso.Deck.new("deck")) == nil
    assert duration(Expresso.Deck.new("deck", %{duration: 15})) == 900_000
    assert duration(Expresso.Deck.new("deck", %{duration: 0})) == nil
    assert duration(Expresso.Deck.new("deck", %{duration: "15"})) == nil
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
