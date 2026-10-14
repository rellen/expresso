defmodule Expresso.MediaTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.{Embed, Video}
  alias Expresso.Media

  @poster "test/fixtures/dot.png"

  defp deck(elements), do: Builder.deck([Builder.slide("one", elements: elements)])

  defp indexes(deck, module),
    do: for(element <- Media.numbered(deck, module), do: {element.src, element.index})

  test "number/3 gives two elements with the same file the same number" do
    deck =
      [
        Builder.video("a.webm", title: "a", poster: @poster),
        Builder.video("b.webm", title: "b", poster: @poster),
        Builder.video("a.webm", title: "c", poster: @poster)
      ]
      |> deck()
      |> Media.number(Video)

    assert indexes(deck, Video) == [{"a.webm", 0}, {"b.webm", 1}]
  end

  test "an embed gets a number of its own, also for the same page" do
    deck =
      [
        Builder.embed("https://example.com/", title: "a"),
        Builder.embed("https://example.com/", title: "b")
      ]
      |> deck()
      |> Embed.number()

    assert indexes(deck, Embed) == [{"https://example.com/", 0}, {"https://example.com/", 1}]
  end
end
