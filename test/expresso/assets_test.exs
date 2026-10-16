defmodule Expresso.AssetsTest do
  use ExUnit.Case, async: true

  alias Expresso.{Assets, Builder}

  doctest Assets

  @image "examples/animations/clip.png"

  defp uri(char), do: "data:image/png;base64," <> String.duplicate(char, 1100)

  test "a poster and a src keep their own names" do
    html =
      ~s(<video poster="#{uri("A")}" src="#{uri("B")}"></video>) <>
        ~s(<video poster="#{uri("A")}" src="#{uri("B")}"></video>)

    assert Assets.dedupe(html) ==
             ~s(<video data-asset-0="poster" poster="#{uri("A")}" data-asset-1="src" src="#{uri("B")}"></video>) <>
               ~s(<video data-asset-poster="0" data-asset-src="1"></video>)
  end

  test "a data URI that occurs one time, and a short one, stay" do
    short = "data:image/png;base64,AAAA"
    html = ~s(<img src="#{uri("A")}"><img src="#{short}"><img src="#{short}">)

    assert Assets.dedupe(html) == html
  end

  test "a slide with an image in two steps holds the image one time" do
    html =
      [
        Builder.slide("photo",
          elements: [
            Builder.image(@image, alt: "A test pattern"),
            Builder.pause(),
            Builder.text_area(text: "b")
          ]
        )
      ]
      |> Builder.deck(name: "photo")
      |> Expresso.Deck.render()

    data = "data:image/png;base64," <> Base.encode64(File.read!(@image))

    assert length(String.split(html, data)) == 2

    document = LazyHTML.from_document(html)
    copies = LazyHTML.query(document, "img[data-asset-src]")

    images = LazyHTML.query(document, "img")

    assert Enum.count(images) > 1
    assert Enum.count(copies) == Enum.count(images) - 1
    assert Enum.all?(copies, &(LazyHTML.attribute(&1, "alt") == ["A test pattern"]))
  end
end
