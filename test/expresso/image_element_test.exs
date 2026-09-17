defmodule Expresso.Element.ImageTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.Image
  alias Expresso.Overlay

  @png "test/fixtures/dot.png"

  defmodule ImageDeck do
    use Expresso

    name "image deck"

    slide "picture" do
      image "test/fixtures/dot.png", alt: "a red dot"
    end

    slide "wide" do
      image "test/fixtures/dot.png" do
        alt "a wide dot"
        width "60vw"
      end
    end

    slide "steps" do
      auto_reveal true

      image "test/fixtures/dot.png"

      text_box do
        image "test/fixtures/dot.png" do
          at 2
          on 2, state: :alert
        end
      end
    end
  end

  defp document(deck), do: deck |> Expresso.parse() |> Expresso.Deck.render()

  describe "new/3" do
    test "makes an image with a path" do
      assert Image.new(@png) == %Image{src: @png, alt: nil, width: nil}
      assert Image.new(@png, "a dot").alt == "a dot"
      assert Image.new(@png, "a dot", "60vw").width == "60vw"
    end
  end

  describe "the DSL entity" do
    test "takes the path as its first argument" do
      [slide, _, _] = Expresso.parse(ImageDeck).slides

      assert [%Image{src: @png, alt: "a red dot"}] = slide.elements
    end

    test "goes at the level of the slide and inside a text box" do
      [_, _, slide] = Expresso.parse(ImageDeck).slides

      assert [%Image{}, %{elements: [%Image{}]}] = slide.elements
    end

    test "takes the at option and the on entity" do
      [_, _, slide] = Expresso.parse(ImageDeck).slides
      [_, %{elements: [image]}] = slide.elements

      assert %Image{at: %Overlay{pairs: [{2, 2}]}, steps: [2]} = image
      assert [%{state: :alert, steps: [2]}] = image.on
    end

    test "takes the implicit specification of auto_reveal" do
      [_, _, slide] = Expresso.parse(ImageDeck).slides
      [image, _] = slide.elements

      assert image.steps == [1, 2]
    end
  end

  describe "render/1" do
    setup do
      {:ok, document: ImageDeck |> document() |> Floki.parse_document!()}
    end

    test "writes an img element with the bytes of the file", %{document: document} do
      [img] = Floki.find(document, "#slide-1 .image img")
      ["data:image/png;base64," <> encoded] = Floki.attribute([img], "src")

      assert Base.decode64!(encoded) == File.read!(@png)
    end

    test "writes the alt option", %{document: document} do
      assert document |> Floki.find("#slide-1 .image img") |> Floki.attribute("alt") ==
               ["a red dot"]
    end

    test "writes an empty alt attribute for an image with no alt option", %{document: document} do
      assert document |> Floki.find("#slide-3 .image img") |> Floki.attribute("alt") == ["", ""]
    end

    test "writes the width option as a custom property on the root tag", %{document: document} do
      assert document |> Floki.find("#slide-2 .image") |> Floki.attribute("style") ==
               ["--image-width: 60vw"]
    end

    test "writes no style attribute for an image with no width option", %{document: document} do
      assert document |> Floki.find("#slide-1 .image") |> Floki.attribute("style") == []
    end

    test "escapes a width that holds a quotation mark" do
      image = %Image{src: @png, width: ~s(60vw" onload="x)}

      assert %{overlay: [{"style", style}]} = Image.get_assigns(image)
      assert style == ~s(--image-width: 60vw" onload="x)

      html = Image.render(%{src: "x", alt: "", overlay: [{"style", style}]})
      refute Phoenix.HTML.safe_to_string(html) =~ ~s(onload=")
    end

    test "writes the overlay attributes on the root tag", %{document: document} do
      [_, nested] = Floki.find(document, "#slide-3 .image")

      assert Floki.attribute([nested], "data-on") == ["2"]
      assert Floki.attribute([nested], "data-el") == ["s3-e3"]
    end

    test "raises for a file that it cannot read" do
      source = """
      defmodule Expresso.Element.ImageTest.MissingDeck do
        use Expresso

        slide do
          image "no/such/file.png"
        end
      end
      """

      [{module, _}] = Code.compile_string(source)

      assert_raise ArgumentError, ~r/cannot read the image "no\/such\/file.png"/, fn ->
        document(module)
      end
    end
  end
end
