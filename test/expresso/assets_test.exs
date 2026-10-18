defmodule Expresso.AssetsTest do
  use ExUnit.Case, async: true

  alias Expresso.{Assets, Builder}

  doctest Assets

  @image "examples/animations/clip.png"

  defp uri(char), do: "data:image/png;base64," <> String.duplicate(char, 1100)

  test "a src, an href and an xlink:href keep their own names" do
    html =
      ~s(<img src="#{uri("B")}"><image href="#{uri("A")}"/><image xlink:href="#{uri("C")}"/>)

    assert Assets.dedupe(html <> html) ==
             ~s(<img data-asset-0="src" src="#{uri("B")}">) <>
               ~s(<image data-asset-1="href" href="#{uri("A")}"/>) <>
               ~s(<image data-asset-2="xlink:href" xlink:href="#{uri("C")}"/>) <>
               ~s(<img data-asset-src="0"><image data-asset-href="1"/><image data-asset-href="2"/>)
  end

  test "a poster attribute stays as it is, because no element writes one" do
    html = ~s(<video poster="#{uri("A")}"></video>)
    assert Assets.dedupe(html <> html) == html <> html
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
