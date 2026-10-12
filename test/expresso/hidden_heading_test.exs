defmodule Expresso.HiddenHeadingTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder

  defp document(slides, opts \\ []) do
    slides
    |> Builder.deck(opts)
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
  end

  defp hidden(document) do
    document |> Floki.find(".screen .slide-hidden-heading") |> Enum.map(&Floki.text/1)
  end

  # A slide template that writes its title as an h2, as the old Line 4 talk did.
  defmodule PartTemplate do
    use Expresso.Template

    def render(assigns) do
      temple do
        h2 do
          Map.get(@metadata, :heading, "")
        end
      end
    end
  end

  test "a slide with a heading gets no hidden heading" do
    assert [Builder.slide("start", heading: "Supervisors")] |> document() |> hidden() == []
  end

  test "a slide with no heading gets a hidden h1 with its name, or its number" do
    document =
      document([
        Builder.slide("the picture", elements: [Builder.image("test/fixtures/dot.png")]),
        Builder.slide(elements: [Builder.image("test/fixtures/dot.png")])
      ])

    assert hidden(document) == ["the picture", "Slide 2 of 2"]
    assert document |> Floki.find(".screen h1.slide-hidden-heading") |> length() == 2
  end

  test "a slide template with no h1 gets a hidden h1 with the heading" do
    document = document([Builder.slide("part", heading: "The line", template: PartTemplate)])

    assert hidden(document) == ["The line"]
    assert document |> Floki.find(".screen h2") |> Floki.text() == "The line"
  end

  test "sr_heading false gives the slide no hidden heading" do
    slide =
      Builder.slide("photo",
        sr_heading: false,
        elements: [Builder.image("test/fixtures/dot.png")]
      )

    assert [slide] |> document() |> hidden() == []
  end

  test "each page of the handout view gets the hidden heading too" do
    pages =
      [Builder.slide("photo", elements: [Builder.image("test/fixtures/dot.png")])]
      |> document()
      |> Floki.find(".handout-page .slide-hidden-heading")

    assert length(pages) == 1
  end

  test "the title of a deck with no name is the first heading of the deck" do
    title =
      [Builder.slide("a"), Builder.slide("b", heading: "Supervisors")]
      |> document()
      |> Floki.find("title")
      |> Floki.text()

    assert title == "Supervisors"
  end

  test "the DSL takes sr_heading" do
    defmodule PhotoDeck do
      use Expresso

      slide "photo" do
        sr_heading false
        image "test/fixtures/dot.png"
      end
    end

    assert {:ok, deck} = Expresso.to_deck(PhotoDeck)
    assert hd(deck.slides).metadata.sr_heading == false
  end
end
