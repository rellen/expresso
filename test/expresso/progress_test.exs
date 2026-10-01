defmodule Expresso.ProgressTest do
  use ExUnit.Case, async: true

  defmodule ShownDeck do
    use Expresso

    name "shown deck"

    slide do
      text_box do
        text_area(text: "One")
      end
    end
  end

  defmodule HiddenDeck do
    use Expresso

    name "hidden deck"
    progress false

    slide do
      text_box do
        text_area(text: "One")
      end
    end
  end

  defp document(deck) do
    deck |> Expresso.Deck.render() |> Floki.parse_document!()
  end

  defp progress(deck) do
    deck |> document() |> Floki.find("body") |> Floki.attribute("data-progress")
  end

  test "a deck from the DSL shows the progress bar without the option" do
    assert Expresso.parse(ShownDeck).metadata == %{
             progress: true,
             handout: :all,
             print_notes: true,
             slide_numbers: false,
             duration: nil,
             transition: :fade,
             effect: :fade,
             speed: nil,
             easing: nil,
             css: nil,
             theme: :default
           }

    assert progress(Expresso.parse(ShownDeck)) == ["true"]
  end

  test "the progress option false hides the progress bar at the start" do
    assert Expresso.parse(HiddenDeck).metadata == %{
             progress: false,
             handout: :all,
             print_notes: true,
             slide_numbers: false,
             duration: nil,
             transition: :fade,
             effect: :fade,
             speed: nil,
             easing: nil,
             css: nil,
             theme: :default
           }

    assert progress(Expresso.parse(HiddenDeck)) == ["false"]
  end

  test "a deck struct shows the progress bar without the key" do
    assert progress(Expresso.Deck.new("deck")) == ["true"]
    assert progress(Expresso.Deck.new("deck", %{progress: false})) == ["false"]
  end

  test "a deck with no metadata shows the progress bar" do
    deck = %Expresso.Deck{name: "deck", metadata: nil, slides: []}
    assert progress(deck) == ["true"]
  end

  test "the document holds one progress bar, and the style sheet gives it the width of --fraction" do
    bars = ShownDeck |> Expresso.parse() |> document() |> Floki.find("#progress")

    assert length(bars) == 1
    assert Floki.attribute(bars, "style") == []
    assert Expresso.Theme.uses?(:fraction)
  end

  test "the theme uses the two custom properties of the progress bar" do
    assert Expresso.Theme.uses?(:"progress-color")
    assert Expresso.Theme.uses?(:"progress-height")
  end
end
