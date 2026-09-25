defmodule Expresso.SlideNumbersTest do
  use ExUnit.Case, async: true

  # Three slides. Slide 2 has two steps, so the handout view has two pages for
  # it.
  defmodule NumberedDeck do
    use Expresso

    name "numbered deck"
    slide_numbers true

    slide "title" do
      text_box do
        text_area(text: "Title")
      end
    end

    slide "two" do
      steps 2

      text_box do
        text_area(text: "Two")
      end
    end

    slide "three" do
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

    slide "two" do
      text_box do
        text_area(text: "Two")
      end
    end
  end

  defp document(deck) do
    deck |> Expresso.Deck.render() |> Floki.parse_document!()
  end

  # The text of the number in each slide of the present view, or nil for a
  # slide with no number.
  defp present(document) do
    for slide <- Floki.find(document, "section.slide") do
      case Floki.find(slide, ".slide-number") do
        [] -> nil
        found -> Floki.text(found)
      end
    end
  end

  # The text of the number in each page of the handout view, or nil.
  defp handout(document) do
    for page <- Floki.find(document, ".handout-page") do
      case Floki.find(page, ".slide-number") do
        [] -> nil
        found -> Floki.text(found)
      end
    end
  end

  test "a deck from the DSL shows no slide number without the option" do
    deck = Expresso.parse(PlainDeck)

    assert deck.metadata.slide_numbers == false
    assert deck |> document() |> Floki.find(".slide-number") == []
  end

  test "slide_numbers true shows the number and the total, and slide 1 shows no number" do
    deck = Expresso.parse(NumberedDeck)
    document = document(deck)

    assert deck.metadata.slide_numbers == true
    assert present(document) == [nil, "2 / 3", "3 / 3"]
    assert handout(document) == [nil, "2 / 3", "2 / 3", "3 / 3"]
  end

  test "the number is in the row of the footer, after the footer of the template" do
    [row] =
      NumberedDeck
      |> Expresso.parse()
      |> document()
      |> Floki.find("#slide-2 > div:last-child")

    assert Floki.find(row, ".footer") != []
    assert row |> Floki.find(".slide-number") |> Floki.text() == "2 / 3"
  end

  test "a deck from the imperative API takes slide_numbers from its metadata" do
    deck =
      Enum.reduce(1..2, Expresso.Deck.new("deck"), fn number, deck ->
        Expresso.Deck.add_slide(deck, "slide #{number}", %{}, [])
      end)

    assert deck |> document() |> present() == [nil, nil]

    numbered = %{deck | metadata: %{slide_numbers: true}}
    assert numbered |> document() |> present() == [nil, "2 / 2"]
  end

  test "the default footer has no text" do
    assert NumberedDeck |> Expresso.parse() |> document() |> Floki.find(".footer") |> Floki.text() ==
             ""
  end
end
