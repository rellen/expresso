defmodule Expresso.E2E.AssetsTest do
  use Expresso.E2E, async: false

  # One image on a slide of two steps: the present view, the menu and each page
  # of the handout view show it, and the document holds it one time.
  defmodule Deck do
    use Expresso

    name "assets deck"

    slide "photo" do
      heading "A photo"

      image "examples/animations/clip.png" do
        alt "A test pattern"
      end

      pause()
      text_area(text: "The second step")
    end
  end

  test "each copy of an image shows it after the load", %{page: page, tmp_dir: tmp_dir} do
    page |> open(render(Deck, tmp_dir)) |> press("p")

    wait_for(page, "Array.from(document.images).every((image) => image.complete)")

    images =
      js(page, """
      Array.from(document.images).map((image) =>
        [image.getAttribute("src").slice(0, 22), image.naturalWidth])
      """)

    assert length(images) > 1
    assert Enum.all?(images, fn [src, width] -> src == "data:image/png;base64," and width > 0 end)
  end
end
